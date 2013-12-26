//
//  TelepresenceManager.h
//  TelepresenceManager
//
//  Created by Andy on 26/12/13.
//  Copyright (c) 2013 Andy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Opentok/Opentok.h>

FOUNDATION_EXPORT NSString *const TelepresenceManagerNotificationId;

typedef enum : NSUInteger {
    TPM_SessionConnected,
    TPM_SessionDisconnected,
    TPM_SessionFailedWithError,
    TPM_StreamReceived,
    TPM_StreamDropped,
    TPM_PublisherStartedStreaming,
    TPM_PublisherStoppedStreaming,
    TPM_PublisherFailedStreaming,
    TPM_PublisherCameraPositionChanged,
    TPM_SubscriberVideoDisabled,
    TPM_SubscriberVideoDataReceieved,
    TPM_SubscriberDidConnectToStream,
    TPM_SubscriberFailedToConnectToStream,
    TPM_SubscriberVideoDimensionsChanged,
    TPM_ClientJoinedSession,
    TPM_ClientLeftSession,
    TPM_CallSignalReceived,
    TPM_CallSignalSent,
    TPM_MessageReceived,
    TPM_MessageSent,
} TelepresenceNotification;

typedef enum : NSUInteger {
    TPMCallSignal_Calling = 1,
    TPMCallSignal_CallAccepted,
    TPMCallSignal_CallRejected,
    TPMCallSignal_CallBusy,
} TPMCallSignal;

typedef enum : NSUInteger {
    TPLoggingLevel_Session        = (1 << 0),
    TPLoggingLevel_Stream         = (1 << 1),
    TPLoggingLevel_Connection     = (1 << 2),
    TPLoggingLevel_Publisher      = (1 << 3),
    TPLoggingLevel_Subscriber     = (1 << 4),
    TPLoggingLevel_Messaging      = (1 << 5),
    TPLoggingLevel_CallSignalling = (1 << 6),
} TPLoggingLevel;

@interface TelepresenceManager : NSObject

//@property (nonatomic, weak) UIView *localVideoView;
//@property (nonatomic, weak) UIView *remoteVideoView;
@property (nonatomic, strong, readonly) NSMutableDictionary *clientsInSession;
@property (nonatomic, strong, readonly) NSMutableArray *autoSubscribeConnectionIds;
@property (nonatomic, strong, readonly) NSMutableDictionary *streamsInSession;
@property (nonatomic, strong, readonly) OTSession *session;
@property (nonatomic, strong, readonly) OTPublisher *publisher;
@property (nonatomic, strong, readonly) NSMutableDictionary *subscribers;

@property (nonatomic, assign) bool publishAudio;
@property (nonatomic, assign) bool publishVideo;
@property (nonatomic, assign) bool subscribeAudio;
@property (nonatomic, assign) bool subscribeVideo;

@property (nonatomic, assign) bool autoSendBusySignal;

@property (nonatomic, assign) TPLoggingLevel loggingLevel;

+(id)sharedInstance;

-(NSString *) nameForTelepresenceNotification:(TelepresenceNotification)telepresenceNotification;
+(NSString *) nameForTelepresenceNotification:(TelepresenceNotification)telepresenceNotification;

-(void) sendMessageToConnectionId:(NSString *)connectionId type:(NSString *)type data:(id)data;
-(void) sendMessageToAllConnectionsWithType:(NSString *)type data:(id)data;

-(void) answerCallFromConnectionId:(NSString *)connectionId;
-(void) callConnectionId:(NSString *)connectionId;

-(void) connectToSessionToken:(NSString *)sessionToken withApiKey:(NSString *)apiKey;
-(void) disconnectFromSession;
-(void) publish;
-(void) unpublish;
-(void) subscribeToStreamId:(NSString *)streamId;
-(void) unsubscribeFromStreamId:(NSString *)streamId;

@end
