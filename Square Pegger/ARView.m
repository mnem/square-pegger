//
//  ARView.m
//  Square Pegger
//
//  Created by David Wagner on 06/08/2015.
//  Copyright (c) 2015 David Wagner. All rights reserved.
//

#import "ARView.h"

@import AVFoundation;

@interface ARView () <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, strong) AVCaptureSession *captureSession;

@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) CAShapeLayer *overlayLayer;

@property (nonatomic, strong) CIDetector *detector;

@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) UIImage *image;
@end

@implementation ARView

#pragma mark - Lifecycle

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)dealloc
{
    [self stop];
}

#pragma mark - AVSession

- (void)setup {
    // Create the session and add the camera input
    self.captureSession = [[AVCaptureSession alloc] init];
    self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto;
    
    AVCaptureDevice *camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:camera error:&error];
    if (!input) {
        NSLog(@"Failed to create camera capture device: %@", error);
        self.captureSession = nil;
        return;
    }
    if (![self.captureSession canAddInput:input]) {
        NSLog(@"Cannot start session with camera input");
        self.captureSession = nil;
        return;
    }
    [self.captureSession addInput:input];
    
    // Setup the video data output
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    output.alwaysDiscardsLateVideoFrames = YES;
    output.videoSettings = @{(__bridge NSString*)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};
    dispatch_queue_t queue = dispatch_queue_create("com.noiseandheat.io.Square-Pegger.videooutput", DISPATCH_QUEUE_SERIAL);
    [output setSampleBufferDelegate:self queue:queue];
    if (![self.captureSession canAddOutput:output]) {
        NSLog(@"Cannot start session with video output");
        self.captureSession = nil;
        return;
    }
    [self.captureSession addOutput:output];
    
    // Add the preview layer
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    self.previewLayer.opacity = 0.5;
    [self.layer addSublayer:self.previewLayer];
    
    // Add the overlay layer
    self.overlayLayer = [CAShapeLayer layer];
    self.overlayLayer.fillColor = nil;
    self.overlayLayer.strokeColor = [UIColor yellowColor].CGColor;
    self.overlayLayer.lineWidth = 10;
    self.overlayLayer.lineDashPhase = 0.1;
    [self.layer addSublayer:self.overlayLayer];
    
    // Display link
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick)];
    
    // Feature detector
    self.detector = [CIDetector detectorOfType:CIDetectorTypeRectangle
                                       context:nil
                                       options:@{CIDetectorAccuracy : CIDetectorAccuracyHigh, CIDetectorAspectRatio : @(2.0)}];
}

- (void)start {
    if (!self.captureSession) {
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0L), ^{
        [self.captureSession startRunning];
    });
    
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)stop {
    if (!self.captureSession) {
        return;
    }
    
    [self.displayLink removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [self.captureSession stopRunning];
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.previewLayer.frame = self.bounds;
    self.overlayLayer.frame = self.bounds;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)buffer
       fromConnection:(AVCaptureConnection *)connection {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(buffer);
    CIImage *cim = [CIImage imageWithCVPixelBuffer:imageBuffer];
    cim = [cim imageByApplyingTransform:CGAffineTransformMakeRotation(-M_PI_2)];
   
    NSArray *features = [self.detector featuresInImage:cim];
    if (features.count > 0) {
        CIRectangleFeature *feature = features[0];
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:feature.topLeft];
        [path addLineToPoint:feature.topRight];
        [path addLineToPoint:feature.bottomRight];
        [path addLineToPoint:feature.bottomLeft];
        [path closePath];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.overlayLayer.path = path.CGPath;
        });
    }
    
    self.image = [UIImage imageWithCIImage:cim];
}

#pragma mark - Tick

- (void)tick {
    [self setNeedsDisplay];
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect {
    if (self.image) {
        CGRect bounds = self.bounds;
        CGFloat aspect = self.image.size.width / self.image.size.height;
        CGRect out;
        if (bounds.size.width / aspect <= bounds.size.height) {
            out = CGRectMake(0, 0, bounds.size.width, bounds.size.width / aspect);
        } else {
            out = CGRectMake(0, 0, bounds.size.height * aspect, bounds.size.height);
        }
        
        out.origin.x = (bounds.size.width - out.size.width) / 2;
        out.origin.y = (bounds.size.height - out.size.height) / 2;
        
//        [self.image drawInRect:out];
        
        CGFloat scale = out.size.width / self.image.size.width;
        CGAffineTransform t = CGAffineTransformIdentity;
        t = CGAffineTransformRotate(t, M_PI_2);
        t = CGAffineTransformScale(t, scale, scale);
        self.overlayLayer.affineTransform = t;
    }
}

@end
