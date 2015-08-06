//
//  ViewController.m
//  Square Pegger
//
//  Created by David Wagner on 06/08/2015.
//  Copyright (c) 2015 David Wagner. All rights reserved.
//

#import "ViewController.h"
#import "ARView.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet ARView *arView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.arView start];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
