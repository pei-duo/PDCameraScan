//
//  PDCameraScanViewController.m
//  DiErZhouKaoShi
//
//  Created by 裴铎 on 2018/7/16.
//  Copyright © 2018年 裴铎. All rights reserved.
//

#import "PDCameraScanViewController.h"

#import "PDCameraScanView.h"//扫描界面头文件
#import <AVFoundation/AVFoundation.h>  //引用AVFoundation框架

@interface PDCameraScanViewController ()<
AVCaptureMetadataOutputObjectsDelegate> //遵守AVCaptureMetadataOutputObjectsDelegate协议
@property ( strong , nonatomic ) AVCaptureDevice * device; //捕获设备，默认后置摄像头
@property ( strong , nonatomic ) AVCaptureDeviceInput * input; //输入设备
@property ( strong , nonatomic ) AVCaptureMetadataOutput * output;//输出设备，需要指定他的输出类型及扫描范围
@property ( strong , nonatomic ) AVCaptureSession * session; //AVFoundation框架捕获类的中心枢纽，协调输入输出设备以获得数据
@property ( strong , nonatomic ) AVCaptureVideoPreviewLayer * previewLayer;//展示捕获图像的图层，是CALayer的子类
@property (nonatomic,strong)UIView *scanView;//定位扫描框在哪个位置

@end

@implementation PDCameraScanViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    //屏幕的宽度
    CGFloat kScreen_Width = [UIScreen mainScreen].bounds.size.width;
    
    //定位扫描框在屏幕正中央，并且宽高为200的正方形
    self.scanView = [[UIView alloc]initWithFrame:CGRectMake((kScreen_Width-200)/2, (self.view.frame.size.height-200)/2, 200, 200)];
    [self.view addSubview:self.scanView];
    
    //设置扫描界面（包括扫描界面之外的部分置灰，扫描边框等的设置）,后面设置
    PDCameraScanView *clearView = [[PDCameraScanView alloc]initWithFrame:self.view.frame];
    [self.view addSubview:clearView];
    
    //初始化并启动扫描
    [self startScan];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


/**
 开始扫描
 */
- (void)startScan
{
    // 1.判断输入能否添加到会话中
    if (![self.session canAddInput:self.input]) return;
    [self.session addInput:self.input];
    
    
    // 2.判断输出能够添加到会话中
    if (![self.session canAddOutput:self.output]) return;
    [self.session addOutput:self.output];
    
    // 4.设置输出能够解析的数据类型
    // 注意点: 设置数据类型一定要在输出对象添加到会话之后才能设置
    //设置availableMetadataObjectTypes为二维码、条形码等均可扫描，如果想只扫描二维码可设置为
    // [self.output setMetadataObjectTypes:@[AVMetadataObjectTypeQRCode]];
    
    self.output.metadataObjectTypes = self.output.availableMetadataObjectTypes;
    
    // 5.设置监听监听输出解析到的数据
    [self.output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    
    // 6.添加预览图层
    [self.view.layer insertSublayer:self.previewLayer atIndex:0];
    self.previewLayer.frame = self.view.bounds;
    
    // 8.开始扫描
    [self.session startRunning];
}


/**
 扫描结束回调
 下面是接收扫描结果的代理AVCaptureMetadataOutputObjectsDelegate:
 */
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    [self.session stopRunning];   //停止扫描
    //我们捕获的对象可能不是AVMetadataMachineReadableCodeObject类，所以要先判断，不然会崩溃
    if (![[metadataObjects lastObject] isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) {
        [self.session startRunning];
        return;
    }
    // id 类型不能点语法,所以要先去取出数组中对象
    AVMetadataMachineReadableCodeObject *object = [metadataObjects lastObject];
    if ( object.stringValue == nil ){
        [self.session startRunning];
    }
    
    NSLog(@"扫描结束了 %@",object);
    
}

/**
 调用相册
 */
- (void)choicePhoto{
    //调用相册
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc]init];
    //UIImagePickerControllerSourceTypePhotoLibrary为相册
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    
    //设置代理UIImagePickerControllerDelegate和UINavigationControllerDelegate
    imagePicker.delegate = self;
    
    [self presentViewController:imagePicker animated:YES completion:nil];
}

//选中图片的回调
-(void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    //取出选中的图片
    UIImage *pickImage = info[UIImagePickerControllerOriginalImage];
    NSData *imageData = UIImagePNGRepresentation(pickImage);
    CIImage *ciImage = [CIImage imageWithData:imageData];
    
    //创建探测器
    //CIDetectorTypeQRCode表示二维码，这里选择CIDetectorAccuracyLow识别速度快
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{CIDetectorAccuracy: CIDetectorAccuracyLow}];
    NSArray *feature = [detector featuresInImage:ciImage];
    
    //取出探测到的数据
    for (CIQRCodeFeature *result in feature) {
        NSString *content = result.messageString;// 这个就是我们想要的值
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark 懒加载

//下面初始化AVCaptureSession和AVCaptureVideoPreviewLayer:
- (AVCaptureSession *)session
{
    if (_session == nil) {
        _session = [[AVCaptureSession alloc] init];
    }
    return _session;
}

- (AVCaptureVideoPreviewLayer *)previewLayer
{
    if (_previewLayer == nil) {
        //负责图像渲染出来
        _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    }
    return _previewLayer;
}

/**
 这里设置输出设备要注意rectOfInterest属性的设置，一般默认是CGRect(x: 0, y: 0, width: 1, height: 1),
 全屏都能读取的，但是读取速度较慢。
 注意rectOfInterest属性的传人的是比例。
 比例是根据扫描容器的尺寸比上屏幕尺寸（注意要计算的时候要计算导航栏高度，有的话需减去）。
 参照的是横屏左上角的比例，而不是竖屏。
 所以我们再设置的时候要调整方向如下面所示。
 */
- (AVCaptureMetadataOutput *)output{
    if (_output == nil) {
        //初始化输出设备
        _output = [[AVCaptureMetadataOutput alloc] init];
        
        // 1.获取屏幕的frame
        CGRect viewRect = self.view.frame;
        // 2.获取扫描容器的frame
        CGRect containerRect = self.scanView.frame;
        
        CGFloat x = containerRect.origin.y / viewRect.size.height;
        CGFloat y = containerRect.origin.x / viewRect.size.width;
        CGFloat width = containerRect.size.height / viewRect.size.height;
        CGFloat height = containerRect.size.width / viewRect.size.width;
        //rectOfInterest属性设置设备的扫描范围
        _output.rectOfInterest = CGRectMake(x, y, width, height);
    }
    return _output;
    
    /**网上还有一种是根据AVCaptureInputPortFormatDescriptionDidChangeNotification通知设置的，也是可行的，自选一种即可
     __weak typeof(self) weakSelf = self;
     [[NSNotificationCenter defaultCenter]addObserverForName:AVCaptureInputPortFormatDescriptionDidChangeNotification
     object:nil
     queue:[NSOperationQueue mainQueue]
     usingBlock:^(NSNotification * _Nonnull note) {
     if (weakSelf){
     //调整扫描区域
     AVCaptureMetadataOutput *output = weakSelf.session.outputs.firstObject;
     output.rectOfInterest = [weakSelf.previewLayer metadataOutputRectOfInterestForRect:weakSelf.scanView.frame];
     }
     }];*/
}


- (AVCaptureDevice *)device{
    if (_device == nil) {
        // 设置AVCaptureDevice的类型为Video类型
        _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    return _device;
}

- (AVCaptureDeviceInput *)input{
    if (_input == nil) {
        //输入设备初始化
        _input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
    }
    return _input;
}

@end
