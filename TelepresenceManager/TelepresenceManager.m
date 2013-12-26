//
//  TelepresenceManager.m
//  TelepresenceManager
//
//  Created by Andy on 26/12/13.
//  Copyright (c) 2013 Andy. All rights reserved.
//

#import "TelepresenceManager.h"
#import <Opentok/Opentok.h>

NSString *const TelepresenceManagerNotificationId = @"TelepresenceManagerNotificaitonId";

@interface TelepresenceManager() <OTPublisherDelegate, OTSessionDelegate, OTSubscriberDelegate>

@end

@implementation TelepresenceManager

static NSString *const TPM_CallSignalType = @"CallSignal";

static BOOL useinside = NO;
static id _sharedObject = nil;

+(id) alloc {
    if (!useinside) {
        @throw [NSException exceptionWithName:@"Singleton Vialotaion" reason:@"You are violating the singleton class usage. Please call +sharedInstance method" userInfo:nil];
    } else {
        return [super alloc];
    }
}

+(id)sharedInstance
{
    static dispatch_once_t p = 0;
    dispatch_once(&p, ^{
        useinside = YES;
        _sharedObject = [[TelepresenceManager alloc] init];
        useinside = NO;
    });
    // returns the same object each time
    return _sharedObject;
}

-(id) init {
    if (self = [super init]) {
        _session = nil;
        _publisher = nil;
        _subscribers = nil;
        _streamsInSession = nil;
        _clientsInSession = nil;
        _autoSubscribeConnectionIds = nil;
    }
    return self;
}

-(bool) isLoggingLevelEnabled:(TPLoggingLevel)level {
    return ((self.loggingLevel & level) != 0);
}

-(NSString *) nameForTelepresenceNotification:(TelepresenceNotification)telepresenceNotification {
    return [TelepresenceManager nameForTelepresenceNotification:telepresenceNotification];
}

+(NSString *) nameForTelepresenceNotification:(TelepresenceNotification)telepresenceNotification {
    NSDictionary *names = @{
                       @(TPM_SessionConnected): @"TPM_SessionConnected",
                       @(TPM_SessionDisconnected): @"TPM_SessionDisconnected",
                       @(TPM_SessionFailedWithError): @"TPM_SessionFailedWithError",
                       @(TPM_StreamReceived): @"TPM_StreamReceived",
                       @(TPM_StreamDropped): @"TPM_StreamDropped",
                       @(TPM_PublisherStartedStreaming): @"TPM_PublisherStartedStreaming",
                       @(TPM_PublisherStoppedStreaming): @"TPM_PublisherStoppedStreaming",
                       @(TPM_PublisherFailedStreaming): @"TPM_PublisherFailedStreaming",
                       @(TPM_PublisherCameraPositionChanged): @"TPM_PublisherCameraPositionChanged",
                       @(TPM_SubscriberVideoDisabled): @"TPM_SubscriberVideoDisabled",
                       @(TPM_SubscriberVideoDataReceieved): @"TPM_SubscriberVideoDataReceieved",
                       @(TPM_SubscriberDidConnectToStream): @"TPM_SubscriberDidConnectToStream",
                       @(TPM_SubscriberFailedToConnectToStream): @"TPM_SubscriberFailedToConnectToStream",
                       @(TPM_SubscriberVideoDimensionsChanged): @"TPM_SubscriberVideoDimensionsChanged",
                       @(TPM_ClientJoinedSession): @"TPM_ClientJoinedSession",
                       @(TPM_ClientLeftSession): @"TPM_ClientLeftSession",
                       @(TPM_CallSignalReceived): @"TPM_CallSignalReceived",
                       @(TPM_CallSignalSent): @"TPM_CallSignalSent",
                       @(TPM_MessageReceived): @"TPM_MessageReceived",
                       @(TPM_MessageSent): @"TPM_MessageSent",
                       };
    return names[@(telepresenceNotification)];
}

-(void) connectToSessionToken:(NSString *)sessionToken withApiKey:(NSString *)apiKey {
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Session]) {
        NSLog(@"SESSION: Connecting to OpenTok session with sessionToken: %@", sessionToken);
    }
    [self.session connectWithApiKey:apiKey token:sessionToken];
}

-(void) disconnectFromSession {
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Session]) {
        NSLog(@"SESSION: Disconnecting from OpenTok session: %@", self.session.sessionId);
    }
    [self.session disconnect];
}

// This method sends a "Call Request" to a specific connection Id
-(void) callConnectionId:(NSString *)connectionId {
    [self sendCallSignallingToConnectionId:connectionId callSignal:TPMCallSignal_Calling];
}

-(void) answerCallFromConnectionId:(NSString *)connectionId {
    [self sendCallSignallingToConnectionId:connectionId callSignal:TPMCallSignal_CallAccepted];
}

-(void) sendCallSignallingToConnectionId:(NSString *)connectionId callSignal:(TPMCallSignal)callSignal {
    
    [self.session signalWithType:TPM_CallSignalType data:@(callSignal) connections:@[self.clientsInSession[connectionId]] completionHandler:^(NSError *error) {
        if (error) {
            if ([self isLoggingLevelEnabled:TPLoggingLevel_CallSignalling]) {
                NSLog(@"MESSAGING: Error sending call signal %@ to %@ error: %@", @(callSignal), connectionId, error);
            }
            return;
        }
        
        if ([self isLoggingLevelEnabled:TPLoggingLevel_CallSignalling]) {
            NSLog(@"MESSAGING: Sent call signal %@ to %@", @(callSignal), connectionId);
        }
        
        [self sendBroadcast:TPM_CallSignalReceived data:@{@"connectionId": connectionId,
                                                          @"callSignal": @(callSignal)}];
    }];
}

-(void) sendMessageToAllConnectionsWithType:(NSString *)type data:(id)data {
    [self.session signalWithType:type data:data completionHandler:^(NSError *error) {
        if (error) {
            if ([self isLoggingLevelEnabled:TPLoggingLevel_Messaging]) {
                NSLog(@"MESSAGING: Error sending message to all clients in session: %@", error);
            }
            return;
        }
        
        if ([self isLoggingLevelEnabled:TPLoggingLevel_Messaging]) {
            NSLog(@"MESSAGING: Sent message to all clients in session");
        }
        
        [self sendBroadcast:TPM_MessageSent data:@{@"type": type,
                                                   @"message": data}];
    }];
}

-(void) sendMessageToConnectionId:(NSString *)connectionId type:(NSString *)type data:(id)data {
    [self.session signalWithType:type data:data connections:@[self.clientsInSession[connectionId]] completionHandler:^(NSError *error) {
        if (error) {
            if ([self isLoggingLevelEnabled:TPLoggingLevel_Messaging]) {
                NSLog(@"MESSAGING: Error sending message to %@ error: %@", connectionId, error);
            }
            return;
        }
        
        if ([self isLoggingLevelEnabled:TPLoggingLevel_Messaging]) {
            NSLog(@"MESSAGING: Sent message to %@", connectionId);
        }
        
        [self sendBroadcast:TPM_MessageSent data:@{@"connectionId": connectionId,
                                                   @"type": type,
                                                   @"message": data}];
    }];
}

-(void) onMessageReceivedFromConnectionId:(NSString *)connectionId type:(NSString *)type data:(id)data {
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Messaging]) {
        NSLog(@"MESSAGING: Received Message");
        NSLog(@"- fromConnection %@", connectionId);
        NSLog(@"- type %@", type);
        NSLog(@"- data %@", data);
    }
    
    if ([type isEqualToString:TPM_CallSignalType]) {
        TPMCallSignal callSignal = [data unsignedIntegerValue];
        [self onCallSignallingMessageReceivedFromConnectionId:connectionId callSignal:callSignal];
        return;
    } else {
        [self sendBroadcast:TPM_MessageReceived data:@{@"connectionId": connectionId,
                                                       @"type": type,
                                                       @"message": data}];
    }
}

-(void) onCallSignallingMessageReceivedFromConnectionId:(NSString *)connectionId callSignal:(TPMCallSignal)callSignal {
    if ([self isLoggingLevelEnabled:TPLoggingLevel_CallSignalling]) {
        NSLog(@"CALLSIGNALING: Received Call Signal");
        NSLog(@"- fromConnection %@", connectionId);
        NSLog(@"- callSignal %d", callSignal);
    }
    
    // If the publisher is not null, then we are currently in a call
    if (self.publisher && self.autoSendBusySignal) {
        [self sendCallSignallingToConnectionId:connectionId callSignal:TPMCallSignal_CallBusy];
        return;
    }
    
    if (callSignal == TPMCallSignal_Calling) {
        [self.autoSubscribeConnectionIds addObject:connectionId];
    } else if (callSignal == TPMCallSignal_CallRejected) {
        [self.autoSubscribeConnectionIds removeObject:connectionId];
    } else if (callSignal == TPMCallSignal_CallBusy) {
        [self.autoSubscribeConnectionIds removeObject:connectionId];
    } else if (callSignal == TPMCallSignal_CallAccepted) {
        [self.autoSubscribeConnectionIds addObject:connectionId];
        [self publish];
    }
    
    [self sendBroadcast:TPM_CallSignalReceived data:@{@"connectionId": connectionId,
                                                      @"callSignal": @(callSignal)}];
}

-(void) publish {
    _publisher = [[OTPublisher alloc] initWithDelegate:self];
    self.publisher.publishAudio = self.publishAudio;
    self.publisher.publishVideo = self.publishVideo;
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Publisher]) {
        NSLog(@"PUBLISHDER: Publishing - Audio=%d,Video=%d", self.publisher.publishAudio, self.publisher.publishVideo);
    }
}

-(void) unpublish {
    [self.publisher setDelegate:nil];
    _publisher = nil;
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Publisher]) {
        NSLog(@"PUBLISHER: Unpublishing");
    }
}

-(void) subscribeToStreamId:(NSString *)streamId {
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Subscriber] && !self.streamsInSession[streamId]) {
        NSLog(@"SUBSCRIBER: Cannot subscribe to stream. Invalid Stream Id: %@", streamId);
        return;
    }
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Subscriber]) {
        NSLog(@"SUBSCRIBER: Subscribing to streamId: %@", streamId);
    }
    OTSubscriber *subscriber = [[OTSubscriber alloc] initWithStream:self.streamsInSession[streamId] delegate:self];
    subscriber.subscribeToAudio = self.subscribeAudio;
    subscriber.subscribeToVideo = self.subscribeVideo;
    self.subscribers[subscriber.stream.streamId] = subscriber;
}

-(void) unsubscribeFromStreamId:(NSString *)streamId {
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Subscriber] && !self.subscribers[streamId]) {
        NSLog(@"SUBSCRIBER: Cannot unsubscribe to stream. Invalid Subscriber Id: %@", streamId);
        return;
    }
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Subscriber]) {
        NSLog(@"SUBSCRIBER: Unsubscribing from stream: %@", streamId);
    }
    OTSubscriber *subscriber = self.subscribers[streamId];
    [subscriber setDelegate:nil];
    [subscriber close];
    [self.subscribers removeObjectForKey:streamId];
}

-(void) sendBroadcast:(TelepresenceNotification)message data:(id)data {
    NSDictionary *broadcastDict;
    if (data) {
        broadcastDict = @{@"broadcast": @(message),
                          @"data": data};
    } else {
        broadcastDict = @{@"broadcast": @(message)};
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:TelepresenceManagerNotificationId object:self userInfo:broadcastDict];
}

-(void) sendBroadcast:(TelepresenceNotification)message {
    [self sendBroadcast:message data:nil];
}

-(void) setSubscribeVideo:(bool)value {
    _subscribeVideo = value;
    for (OTSubscriber *subscriber in [self.subscribers allValues]) {
        [subscriber setSubscribeToVideo:value];
    }
}

-(void) setSubscribeAudio:(bool)value {
    _subscribeAudio = value;
    for (OTSubscriber *subscriber in [self.subscribers allValues]) {
        [subscriber setSubscribeToAudio:value];
    }
}

-(void) setPublishVideo:(bool)value {
    _publishVideo = value;
    if (self.publisher) {
        self.publisher.publishVideo = value;
    }
}

-(void) setPublishAudio:(bool)value {
    _publishAudio = value;
    if (self.publisher) {
        self.publisher.publishAudio = value;
    }
}

#pragma mark - OTSession Delegate Callbacks
/** @name Connecting to a session */

/**
 * Sent when the client connects to the session.
 *
 * @param session The <OTSession> instance that sent this message.
 */
- (void)sessionDidConnect:(OTSession*)session {
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Session]) {
        NSLog(@"SESSION: sessionDidConnect - sessionId=%@", session.sessionId);
    }
    
    _autoSubscribeConnectionIds = [NSMutableArray new];
    _clientsInSession = [NSMutableDictionary new];
    _streamsInSession = [NSMutableDictionary new];
    _subscribers = [NSMutableDictionary new];
    _session = session;
    session.delegate = self;
    [_session receiveSignalType:@"" withHandler:^(NSString *type, id data, OTConnection *fromConnection) {
        [self onMessageReceivedFromConnectionId:fromConnection.connectionId type:type data:data];
    }];
    
    [self sendBroadcast:TPM_SessionConnected data:@{@"sessionId": session.sessionId}];
}

/**
 * Sent when the client disconnects from the session.
 *
 * When a session disconnects, all <OTSubscriber> and <OTPublisher> objects' views are
 * removed from their superviews.
 *
 * @param session The <OTSession> instance that sent this message.
 */
- (void)sessionDidDisconnect:(OTSession*)session {
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Session]) {
        NSLog(@"SESSION: sessionDidDisconnect - session: %@", session.sessionId);
    }
    
    [session setDelegate:nil];
    _session = nil;
    [self.publisher setDelegate:nil];
    _publisher = nil;
    _subscribers = nil;
    _autoSubscribeConnectionIds = nil;
    _clientsInSession = nil;
    _streamsInSession = nil;
    
    [self sendBroadcast:TPM_SessionDisconnected data:@{@"sessionId": session.sessionId}];
}

/**
 * Sent if the session fails to connect, some time after your applications sends the
 * [OTSession connectWithApiKey:token:] message.
 *
 * @param session The <OTSession> instance that sent this message.
 * @param error An <OTError> object describing the issue. The `OTSessionErrorCode` enum
 * (defined in the OTError class) defines values for the `code` property of this object.
 */
- (void)session:(OTSession*)session didFailWithError:(OTError*)error {
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Session]) {
        NSLog(@"SESSION: sessionDidFailWithError - session=%@, error=%@", error, session.sessionId);
    }
    [self sendBroadcast:TPM_SessionFailedWithError data:@{@"sessionId": session.sessionId,
                                                          @"error": error}];
}

/** @name Monitoring streams in a session */

/**
 * Sent when a new stream is created in this session.
 *
 * Note that if your application successfuly publishes to this session, its session delegate is sent
 * an [OTSessionDelegate session:didReceiveStream:] message for its own published stream.
 * You can compare the `stream.connection.connectionId` property with the `session.connection.connectionId`
 * property. (If they matches, the stream is published from your connection.)
 *
 * @param session The OTSession instance that sent this message.
 * @param stream The stream associated with this event.
 */
- (void)session:(OTSession*)session didReceiveStream:(OTStream*)stream {
    // Check whether this is our own stream, if so ignore it
    if ([stream.connection.connectionId isEqualToString:session.connection.connectionId]) {
        return;
    }
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Stream]) {
        NSLog(@"STREAM: sessionDidReceiveStream - sessionId=%@, streamId=%@", session.sessionId, stream.streamId);
    }
    // Add the stream to our dictionary
    self.streamsInSession[stream.streamId] = stream;
    [self sendBroadcast:TPM_StreamReceived data:@{@"sessionId": session.sessionId,
                                                  @"streamId": stream.streamId}];
    
    if ([self.autoSubscribeConnectionIds containsObject:stream.connection.connectionId]) {
        [self subscribeToStreamId:stream.streamId];
    }
}

/**
 * Sent when a stream is no longer published to the session.
 *
 * Note that if your application stops publishing a stream to the session, its session delegate is
 * sent an [OTSessionDelegate session:didDropStream:] message for its own published stream.
 * You can check the stream.connection.connectionId property to see if it matches
 * the `session.connection.connectionId` property. (If it matches, the stream was
 * published from your connection.)
 *
 * When a stream is dropped, the view for any <OTSubscriber> object for the stream is
 * removed from its superview. If the stream corresponds to an <OTPublisher> object,
 * the <OTPublisher> object's view is removed from its superview.
 *
 * @param session The <OTSession> instance that sent this message.
 * @param stream The stream associated with this event.
 */
- (void)session:(OTSession*)session didDropStream:(OTStream*)stream {
    if ([stream.connection.connectionId isEqualToString:session.connection.connectionId]) {
        return;
    }
    // Remove the stream from our dictionary
    [self.streamsInSession removeObjectForKey:stream.streamId];

    if ([self isLoggingLevelEnabled:TPLoggingLevel_Stream]) {
            NSLog(@"STREAM: sessionDidDropStream - streamId=%@, sessionId=%@", stream.streamId, session.sessionId);
    }
    
    [self sendBroadcast:TPM_StreamDropped data:@{@"sessionId": session.sessionId,
                                                 @"streamId": stream.streamId}];
}

/** @name Monitoring connections in a session */

/**
 * Sent when other client connects to the session. The `connection` object represents the client's
 * connection to the session.
 *
 * This message is not sent when your own client connects to the session. The <[OTSessionDelegate sessionDidConnect:]>
 * message is sent when your own client connects to the session.
 *
 * @param session The <OTSession> instance that sent this message.
 * @param connection The new <OTConnection> object.
 */
- (void) session:(OTSession *)session didCreateConnection:(OTConnection*)connection {
    self.clientsInSession[connection.connectionId] = connection;
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Connection]) {
        NSLog(@"CONNECTION: sessionDidCreateConnection - sessionId=%@, connectionId=%@", session.sessionId, connection.connectionId);
    }
    [self sendBroadcast:TPM_ClientJoinedSession data:@{@"connectionId": connection.connectionId,
                                                       @"sessionId": session.sessionId}];
}

/**
 * Sent when another client disconnects from the session. The `connection` object represents the connection
 * that the client had to the session.
 *
 * This message is not sent when your own client disconnects from the session. The <[OTSessionDelegate sessionDidDisconnect:]>
 * message is sent when your own client connects to the session.
 *
 * @param session The <OTSession> instance that sent this message.
 * @param connection The <OTConnection> object for the client that disconnected from the session.
 */
- (void) session:(OTSession*) session didDropConnection:(OTConnection*) connection {
    [self.clientsInSession removeObjectForKey:connection.connectionId];
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Connection]) {
        NSLog(@"CONNECTION: sessionDidDropConnection - sessionId=%@, connectionId=%@", session.sessionId, connection.connectionId);
    }
    
    [self sendBroadcast:TPM_ClientLeftSession data:@{@"connectionId": connection.connectionId,
                                                       @"sessionId": session.sessionId}];
}

#pragma mark - OTSubscriber Delegate Callbacks
/** @name Using subscribers */

/**
 * Sent when the subscriber successfully connects to the stream.
 * @param subscriber The subscriber that generated this event.
 */
- (void)subscriberDidConnectToStream:(OTSubscriber *)subscriber {
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Subscriber]) {
        NSLog(@"SUBSCRIBER: subscriberDidConnectToStream - streamId=%@", subscriber.stream.streamId);
    }
    
    [self.autoSubscribeConnectionIds removeObject:subscriber.stream.connection.connectionId];
    
    [self sendBroadcast:TPM_SubscriberDidConnectToStream data:@{@"streamId": subscriber.stream.streamId}];
}

/**
 * Sent if the subscriber fails to connect to its stream.
 * @param subscriber The subscriber that generated this event.
 * @param error The error (an <OTError> object) that describes this connection error. The
 * `OTSubscriberErrorCode` enum (defined in the OTError class) defines values for the `code`
 * property of this object.
 */
- (void)subscriber:(OTSubscriber*)subscriber didFailWithError:(OTError*)error {
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Subscriber]) {
        NSLog(@"SUBSCRIBER: subscriberDidFailWithError - streamId=%@, error=%@", subscriber.stream.streamId, error);
    }
    
    [self sendBroadcast:TPM_SubscriberFailedToConnectToStream data:@{@"streamId": subscriber.stream.streamId,
                                                                     @"error": error}];
}

/**
 * Sent when the first frame of video has been decoded. Although the
 * subscriber will connect in a relatively short time, video can take
 * more time to synchronize. This message is sent after the
 * <subscriberDidConnectToStream> message is sent.
 * @param subscriber The subscriber that generated this event.
 */
- (void)subscriberVideoDataReceived:(OTSubscriber*)subscriber {
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Subscriber]) {
        NSLog(@"SUBSCRIBER: subscriberVideoDataReceived - streamId=%@", subscriber.stream.streamId);
    }
    //[self.remoteVideoView addSubview:subscriber.view];
    
    [self sendBroadcast:TPM_SubscriberVideoDataReceieved data:@{@"streamId": subscriber.stream.streamId}];
}

/**
 * Sent when the video dimensions of a stream changes. This occurs when a stream published from an iOS device resizes,
 * based on a change in the device orientation.
 *
 * This message is available for WebRTC only.
 *
 * @param stream The stream that changed video dimensions.
 * @param dimensions The new dimensions of the encoded stream.
 */
- (void)stream:(OTStream*)stream didChangeVideoDimensions:(CGSize)dimensions {
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Stream]) {
        NSLog(@"STREAM: streamDidChangeVideoDimensions - streamId=%@, dimensions=(height: %f, width: %f)", stream.streamId, dimensions.height, dimensions.width);
    }
    
    [self sendBroadcast:TPM_SubscriberVideoDimensionsChanged data:@{@"streamId": stream.streamId,
                                                                    @"dimensionsHeight": @(dimensions.height),
                                                                    @"dimensionsWidth": @(dimensions.width)}];
}

/**
 * This message is sent when the OpenTok media server stops sending video to the subscriber.
 * This feature of the OpenTok media server has a subscriber drop the video stream when connectivity degrades.
 * The subscriber continues to receive the audio stream, if there is one.
 *
 * @param subscriber The <OTSubscriber> that will no longer receive video.
 */
- (void)subscriberVideoDisabled:(OTSubscriber*)subscriber {
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Subscriber]) {
        NSLog(@"SUBSCRIBER: subscriberVideoDisabled - streamId=%@", subscriber.stream.streamId);
    }
    //[subscriber.view removeFromSuperview];
    
    [self sendBroadcast:TPM_SubscriberVideoDisabled];
}

#pragma mark - OTPublisher Delegate Callbacks
/**
 * Sent if the publisher encounters an error. After this message is sent,
 * the publisher can be considered fully detached from a session and may
 * be released.
 * @param publisher The publisher that signalled this event.
 * @param error The error (an <OTError> object). The `OTPublisherErrorCode` enum (defined in the OTError class)
 * defines values for the `code` property of this object.
 */
- (void)publisher:(OTPublisher *)publisher didFailWithError:(OTError *)error {
    [publisher setDelegate:nil];
    _publisher = nil;
    
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Publisher]) {
        NSLog(@"PUBLISHER: publisherDidFailWithError - error=%@", error);
    }
    
    [self sendBroadcast:TPM_PublisherFailedStreaming data:@{@"error": error}];
}

/**
 * Sent when the publisher begins streaming device capture data to a session. Note that the session
 * delegate will also receive an <[OTSessionDelegate session:didReceiveStream:]> message for your publisher's stream.
 * @param publisher The publisher that signalled this event.
 */
-(void)publisherDidStartStreaming:(OTPublisher*)publisher {
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Publisher]) {
        NSLog(@"PUBLISHER: publisherDidStartStreaming");
    }
    [self sendBroadcast:TPM_PublisherStartedStreaming];
}

/**
 * Sent when the publisher stops streaming device capture data to a session. Note that the session
 * delegate will also receive an <[OTSessionDelegate session:didDropStream:]> message for your publisher's stream.
 * @param publisher The publisher that signalled this event.
 */
-(void)publisherDidStopStreaming:(OTPublisher*)publisher {
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Publisher]) {
        NSLog(@"PUBLISHER: publisherDidStopStreaming");
    }
    [self sendBroadcast:TPM_PublisherStoppedStreaming];
}

/**
 * Sent when the camera device is changed.
 * @param publisher The publisher that signalled this event.
 * @param position The new camera position.
 */
-(void)publisher:(OTPublisher*)publisher didChangeCameraPosition:(AVCaptureDevicePosition)position {
    if ([self isLoggingLevelEnabled:TPLoggingLevel_Publisher]) {
        NSLog(@"PUBLISHER: publisherDidChangeCameraPosition - position: %d", position);
    }
    [self sendBroadcast:TPM_PublisherCameraPositionChanged data:@{@"cameraPosition": @(position)}];
}

@end
