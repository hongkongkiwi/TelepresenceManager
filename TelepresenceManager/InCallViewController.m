//
//  InCallViewController.m
//  OpenTokHelloWorld
//
//  Created by Andy on 26/12/13.
//
//

#import "InCallViewController.h"
#import "TelepresenceManager.h"

@interface InCallViewController ()

@end

@implementation InCallViewController

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void) viewDidAppear:(BOOL)animated {
    [self subscribeToNotificaitons];
}

- (void) viewWillDisappear:(BOOL)animated {
    [self unsubscribeFromNotifications];
}

- (void)subscribeToNotificaitons {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onTelepresenceManagerNotification:) name:TelepresenceManagerNotificationId object:[TelepresenceManager sharedInstance]];
}

- (void)unsubscribeFromNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TelepresenceManagerNotificationId object:[TelepresenceManager sharedInstance]];
}

- (void) onTelepresenceManagerNotification:(NSNotification *)note {
    NSDictionary *userInfo = note.userInfo;
    
    if (!userInfo) {
        NSLog(@"Invalid TelepresenceManagerNotification - No userInfo dictionary");
        return;
    }
    
    if (!userInfo[@"broadcast"]) {
        NSLog(@"Invalid TelepresenceManagerNotification - No broadcast entry in userInfo dictionary");
        return;
    }
    
    TelepresenceNotification broadcast = [userInfo[@"broadcast"] unsignedIntegerValue];
    NSDictionary *dataDict = userInfo[@"data"];
    
    switch (broadcast) {
        case TPM_SessionConnected:
            break;
        case TPM_SessionDisconnected:
            break;
        case TPM_SessionFailedWithError:
            break;
        case TPM_StreamReceived:
            break;
        case TPM_StreamDropped:
            break;
        case TPM_PublisherStartedStreaming:
            break;
        case TPM_PublisherStoppedStreaming:
            break;
        case TPM_PublisherFailedStreaming:
            break;
        case TPM_PublisherCameraPositionChanged:
            break;
        case TPM_SubscriberVideoDisabled:
            break;
        case TPM_SubscriberVideoDataReceieved:
            break;
        case TPM_SubscriberDidConnectToStream:
            break;
        case TPM_SubscriberFailedToConnectToStream:
            break;
        case TPM_SubscriberVideoDimensionsChanged:
            break;
        case TPM_ClientJoinedSession:
            break;
        case TPM_ClientLeftSession:
            break;
        case TPM_MessageReceived:
            break;
        case TPM_MessageSent:
            break;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
