#import "MPNetworkCommunication.h"
#import "MPMessage.h"
#import "MPSession.h"
#import <UIKit/UIKit.h>
#import "MPConnector.h"
#import "MPStateMachine.h"
#import "MPUpload.h"
#import "MPDevice.h"
#import "MPApplication.h"
#import "MPSegment.h"
#import "MPIConstants.h"
#import "MPZip.h"
#import "MPURLRequestBuilder.h"
#import "MParticleReachability.h"
#import "MPILogger.h"
#import "MPConsumerInfo.h"
#import "MPPersistenceController.h"
#import "MPIUserDefaults.h"
#import "MPDateFormatter.h"
#import "MPIdentityApiRequest.h"
#import "mParticle.h"
#import "MPPersistenceController.h"
#import "MPEnums.h"
#import "MPIdentityDTO.h"
#import "MPIConstants.h"
#import "NSString+MPPercentEscape.h"

NSString *const urlFormat = @"%@://%@%@/%@%@"; // Scheme, URL Host, API Version, API key, path
NSString *const identityURLFormat = @"%@://%@%@/%@"; // Scheme, URL Host, API Version, path
NSString *const modifyURLFormat = @"%@://%@%@/%@/%@"; // Scheme, URL Host, API Version, mpid, path
NSString *const kMPConfigVersion = @"/v4";
NSString *const kMPConfigURL = @"/config";
NSString *const kMPEventsVersion = @"/v2";
NSString *const kMPEventsURL = @"/events";
NSString *const kMPSegmentVersion = @"/v1";
NSString *const kMPSegmentURL = @"/audience";
NSString *const kMPIdentityVersion = @"/v1";
NSString *const kMPIdentityURL = @"";

NSString *const kMPURLScheme = @"https";
NSString *const kMPURLHost = @"nativesdks.mparticle.com";
NSString *const kMPURLHostConfig = @"config2.mparticle.com";
NSString *const kMPURLHostIdentity = @"identity.mparticle.com";

@interface MParticle ()

@property (nonatomic, strong, readonly) MPPersistenceController *persistenceController;
@property (nonatomic, strong, readonly) MPStateMachine *stateMachine;

@end

@interface MPIdentityApiRequest ()

- (NSDictionary<NSString *, id> *)dictionaryRepresentation;

@end


@interface MPIdentityHTTPErrorResponse ()

- (instancetype)initWithJsonObject:(nullable NSDictionary *)dictionary httpCode:(NSInteger) httpCode;
- (instancetype)initWithCode:(MPIdentityErrorResponseCode) code message: (NSString *) message error:(NSError *) error;

@end

@interface MPNetworkCommunication()

@property (nonatomic, strong, readonly) NSURL *segmentURL;
@property (nonatomic, strong, readonly) NSURL *configURL;
@property (nonatomic, strong, readonly) NSURL *eventURL;
@property (nonatomic, strong, readonly) NSURL *identifyURL;
@property (nonatomic, strong, readonly) NSURL *loginURL;
@property (nonatomic, strong, readonly) NSURL *logoutURL;
@property (nonatomic, strong, readonly) NSURL *modifyURL;

@property (nonatomic, strong) NSString *context;
@property (nonatomic, assign) BOOL identifying;

@end

@implementation MPNetworkCommunication

@synthesize configURL = _configURL;
@synthesize eventURL = _eventURL;
@synthesize identifyURL = _identifyURL;
@synthesize loginURL = _loginURL;
@synthesize logoutURL = _logoutURL;
@synthesize identifying = _identifying;

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.identifying = NO;
    
    return self;
}

#pragma mark Private accessors
- (NSURL *)configURL {
    if (_configURL) {
        return _configURL;
    }
    
    MPStateMachine *stateMachine = [MParticle sharedInstance].stateMachine;
    MPApplication *application = [[MPApplication alloc] init];
    NSString *configURLFormat = [urlFormat stringByAppendingString:@"?av=%@&sv=%@"];
    NSString *configHost = [MParticle sharedInstance].networkOptions.configHost ?: kMPURLHostConfig;
    NSString *urlString = [NSString stringWithFormat:configURLFormat, kMPURLScheme, configHost, kMPConfigVersion, stateMachine.apiKey, kMPConfigURL, [application.version percentEscape], kMParticleSDKVersion];
    _configURL = [NSURL URLWithString:urlString];
    
    return _configURL;
}

- (NSURL *)eventURL {
    if (_eventURL) {
        return _eventURL;
    }
    
    MPStateMachine *stateMachine = [MParticle sharedInstance].stateMachine;
    NSString *eventHost = [MParticle sharedInstance].networkOptions.eventsHost ?: kMPURLHost;
    NSString *urlString = [NSString stringWithFormat:urlFormat, kMPURLScheme, eventHost, kMPEventsVersion, stateMachine.apiKey, kMPEventsURL];
    _eventURL = [NSURL URLWithString:urlString];
    
    return _eventURL;
}

- (NSURL *)segmentURL {
    MPStateMachine *stateMachine = [MParticle sharedInstance].stateMachine;
    
    NSString *segmentURLFormat = [urlFormat stringByAppendingString:@"?mpID=%@"];
    NSString *eventHost = [MParticle sharedInstance].networkOptions.eventsHost ?: kMPURLHost;
    NSString *urlString = [NSString stringWithFormat:segmentURLFormat, kMPURLScheme, eventHost, kMPSegmentVersion, stateMachine.apiKey, kMPSegmentURL, [MPPersistenceController mpId]];
    
    NSURL *segmentURL = [NSURL URLWithString:urlString];
    
    return segmentURL;
}

- (NSURL *)identifyURL {
    if (_identifyURL) {
        return _identifyURL;
    }
    NSString *pathComponent = @"identify";
    NSString *identityHost = [MParticle sharedInstance].networkOptions.identityHost ?: kMPURLHostIdentity;
    NSString *urlString = [NSString stringWithFormat:identityURLFormat, kMPURLScheme, identityHost, kMPIdentityVersion, pathComponent];
    _identifyURL = [NSURL URLWithString:urlString];
    
    return _identifyURL;
}

- (NSURL *)loginURL {
    if (_loginURL) {
        return _loginURL;
    }
    
    NSString *pathComponent = @"login";
    NSString *identityHost = [MParticle sharedInstance].networkOptions.identityHost ?: kMPURLHostIdentity;
    NSString *urlString = [NSString stringWithFormat:identityURLFormat, kMPURLScheme, identityHost, kMPIdentityVersion, pathComponent];
    _loginURL = [NSURL URLWithString:urlString];
    
    return _loginURL;
}

- (NSURL *)logoutURL {
    if (_logoutURL) {
        return _logoutURL;
    }
    
    NSString *pathComponent = @"logout";
    NSString *identityHost = [MParticle sharedInstance].networkOptions.identityHost ?: kMPURLHostIdentity;
    NSString *urlString = [NSString stringWithFormat:identityURLFormat, kMPURLScheme, identityHost, kMPIdentityVersion, pathComponent];
    _logoutURL = [NSURL URLWithString:urlString];
    
    return _logoutURL;
}

- (NSURL *)modifyURL {
    NSString *pathComponent = @"modify";
    NSString *identityHost = [MParticle sharedInstance].networkOptions.identityHost ?: kMPURLHostIdentity;
    NSString *urlString = [NSString stringWithFormat:modifyURLFormat, kMPURLScheme, identityHost, kMPIdentityVersion, [MPPersistenceController mpId], pathComponent];
    
    NSURL *modifyURL = [NSURL URLWithString:urlString];
    
    return modifyURL;
}

- (BOOL)identifying {
    @synchronized(self) {
        return _identifying;
    }
}

- (void)setIdentifying:(BOOL)identifying {
    @synchronized(self) {
        _identifying = identifying;
    }
}

#pragma mark Private methods
- (void)processNetworkResponseAction:(MPNetworkResponseAction)responseAction batchObject:(MPUpload *)batchObject {
    [self processNetworkResponseAction:responseAction batchObject:batchObject httpResponse:nil];
}

- (void)processNetworkResponseAction:(MPNetworkResponseAction)responseAction batchObject:(MPUpload *)batchObject httpResponse:(NSHTTPURLResponse *)httpResponse {
    switch (responseAction) {
        case MPNetworkResponseActionDeleteBatch:
            if (!batchObject) {
                return;
            }
            
            [[MParticle sharedInstance].persistenceController deleteUpload:batchObject];
            
            break;
            
        case MPNetworkResponseActionThrottle: {
            NSDate *now = [NSDate date];
            NSDictionary *httpHeaders = [httpResponse allHeaderFields];
            NSTimeInterval retryAfter = 7200; // Default of 2 hours
            NSTimeInterval maxRetryAfter = 86400; // Maximum of 24 hours
            id suggestedRetryAfter = httpHeaders[@"Retry-After"];
            
            if (!MPIsNull(suggestedRetryAfter)) {
                if ([suggestedRetryAfter isKindOfClass:[NSString class]]) {
                    if ([suggestedRetryAfter containsString:@":"]) { // Date
                        NSDate *retryAfterDate = [MPDateFormatter dateFromStringRFC1123:(NSString *)suggestedRetryAfter];
                        if (retryAfterDate) {
                            retryAfter = MIN(([retryAfterDate timeIntervalSince1970] - [now timeIntervalSince1970]), maxRetryAfter);
                            retryAfter = retryAfter > 0 ? retryAfter : 7200;
                        } else {
                            MPILogError(@"Invalid 'Retry-After' date: %@", suggestedRetryAfter);
                        }
                    } else { // Number of seconds
                        @try {
                            retryAfter = MIN([(NSString *)suggestedRetryAfter doubleValue], maxRetryAfter);
                        } @catch (NSException *exception) {
                            retryAfter = 7200;
                            MPILogError(@"Invalid 'Retry-After' value: %@", suggestedRetryAfter);
                        }
                    }
                } else if ([suggestedRetryAfter isKindOfClass:[NSNumber class]]) {
                    retryAfter = MIN([(NSNumber *)suggestedRetryAfter doubleValue], maxRetryAfter);
                }
            }
            
            if ([[MParticle sharedInstance].stateMachine.minUploadDate compare:now] == NSOrderedAscending) {
                [MParticle sharedInstance].stateMachine.minUploadDate = [now dateByAddingTimeInterval:retryAfter];
                MPILogDebug(@"Throttling network for %.0f seconds", retryAfter);
            }
        }
            break;
            
        default:
            [MParticle sharedInstance].stateMachine.minUploadDate = [NSDate distantPast];
            break;
    }
}

#pragma mark Public accessors
- (void)configRequestDidSucceed {
    MPIUserDefaults *userDefaults = [MPIUserDefaults standardUserDefaults];
    userDefaults[kMPLastConfigReceivedKey] = @([NSDate timeIntervalSinceReferenceDate]);
    [userDefaults synchronize];
}

#pragma mark Public methods
- (void)requestConfig:(void(^)(BOOL success, NSDictionary *configurationDictionary, NSString *eTag))completionHandler {
    BOOL shouldSendRequest = YES;
    
    MPIUserDefaults *userDefaults = [MPIUserDefaults standardUserDefaults];
    NSNumber *lastReceivedNumber = userDefaults[kMPLastConfigReceivedKey];
    if (lastReceivedNumber != nil) {
        NSTimeInterval lastConfigReceivedInterval = [lastReceivedNumber doubleValue];
        NSTimeInterval interval = [NSDate timeIntervalSinceReferenceDate];
        NSTimeInterval delta = interval - lastConfigReceivedInterval;
        NSTimeInterval quietInterval = [MPStateMachine environment] == MPEnvironmentDevelopment ? DEBUG_CONFIG_REQUESTS_QUIET_INTERVAL : CONFIG_REQUESTS_QUIET_INTERVAL;
        shouldSendRequest = delta > quietInterval;
    }
    
    if (!shouldSendRequest) {
        completionHandler(YES, nil, nil);
        return;
    }
    
    __weak MPNetworkCommunication *weakSelf = self;
    
    MPILogVerbose(@"Starting config request");
    NSTimeInterval start = [[NSDate date] timeIntervalSince1970];
    
    __block UIBackgroundTaskIdentifier backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    
    if (![MPStateMachine isAppExtension]) {
        backgroundTaskIdentifier = [[MPApplication sharedUIApplication] beginBackgroundTaskWithExpirationHandler:^{
            if (backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
                [[MPApplication sharedUIApplication] endBackgroundTask:backgroundTaskIdentifier];
                backgroundTaskIdentifier = UIBackgroundTaskInvalid;
            }
        }];
    }
    
    MPConnector *connector = [[MPConnector alloc] init];
    NSString *const connectionId = [[NSUUID UUID] UUIDString];
    connector.connectionId = connectionId;
    
    
    
    MPConnectorResponse *response = [connector responseFromGetRequestToURL:self.configURL];
    
    
    NSData *data = response.data;
    NSHTTPURLResponse *httpResponse = response.httpResponse;
    
    __strong MPNetworkCommunication *strongSelf = weakSelf;
    if (!strongSelf) {
        completionHandler(NO, nil, nil);
        return;
    }
    
    if (![MPStateMachine isAppExtension]) {
        if (backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
            [[MPApplication sharedUIApplication] endBackgroundTask:backgroundTaskIdentifier];
            backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        }
    }
    
    NSInteger responseCode = [httpResponse statusCode];
    MPILogVerbose(@"Config Response Code: %ld, Execution Time: %.2fms", (long)responseCode, ([[NSDate date] timeIntervalSince1970] - start) * 1000.0);
    
    if (responseCode == HTTPStatusCodeNotModified) {
        completionHandler(YES, nil, nil);
        [self configRequestDidSucceed];
        return;
    }
    
    MPNetworkResponseAction responseAction = MPNetworkResponseActionNone;
    BOOL success = responseCode == HTTPStatusCodeSuccess || responseCode == HTTPStatusCodeAccepted;
    
    if (!data && success) {
        completionHandler(NO, nil, nil);
        MPILogWarning(@"Failed config request");
        return;
    }
    
    NSDictionary *headersDictionary = [httpResponse allHeaderFields];
    NSString *eTag = headersDictionary[kMPHTTPETagHeaderKey];
    NSDictionary *configurationDictionary = nil;
    success = success && [data length] > 0;
    
    if (!MPIsNull(eTag) && success) {
        MPIUserDefaults *userDefaults = [MPIUserDefaults standardUserDefaults];
        userDefaults[kMPHTTPETagHeaderKey] = eTag;
    }
    
    if (success) {
        @try {
            NSError *serializationError = nil;
            configurationDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&serializationError];
            success = serializationError == nil && [configurationDictionary[kMPMessageTypeKey] isEqualToString:kMPMessageTypeConfig];
        } @catch (NSException *exception) {
            success = NO;
            responseCode = HTTPStatusCodeNoContent;
        }
    } else {
        if (responseCode == HTTPStatusCodeServiceUnavailable || responseCode == HTTPStatusCodeTooManyRequests) {
            responseAction = MPNetworkResponseActionThrottle;
        }
    }
    
    [strongSelf processNetworkResponseAction:responseAction batchObject:nil httpResponse:httpResponse];
    
    if (success && configurationDictionary) {
        completionHandler(success, configurationDictionary, eTag);
        [self configRequestDidSucceed];
    }
}

- (void)requestSegmentsWithTimeout:(NSTimeInterval)timeout completionHandler:(MPSegmentResponseHandler)completionHandler {
    __block UIBackgroundTaskIdentifier backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    
    if (![MPStateMachine isAppExtension]) {
        backgroundTaskIdentifier = [[MPApplication sharedUIApplication] beginBackgroundTaskWithExpirationHandler:^{
            if (backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
                [[MPApplication sharedUIApplication] endBackgroundTask:backgroundTaskIdentifier];
                backgroundTaskIdentifier = UIBackgroundTaskInvalid;
            }
        }];
    }
    
    MPConnector *connector = [[MPConnector alloc] init];
    
    __weak MPNetworkCommunication *weakSelf = self;
    NSDate *fetchSegmentsStartTime = [NSDate date];
    
    MPConnectorResponse *response = [connector responseFromGetRequestToURL:self.segmentURL];
    NSData *data = response.data;
    NSHTTPURLResponse *httpResponse = response.httpResponse;
    NSTimeInterval elapsedTime = [[NSDate date] timeIntervalSinceDate:fetchSegmentsStartTime];
    __strong MPNetworkCommunication *strongSelf = weakSelf;
    if (!strongSelf) {
        completionHandler(NO, nil, elapsedTime, nil);
        return;
    }
    
    if (![MPStateMachine isAppExtension]) {
        if (backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
            [[MPApplication sharedUIApplication] endBackgroundTask:backgroundTaskIdentifier];
            backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        }
    }
    
    if (!data) {
        completionHandler(NO, nil, elapsedTime, nil);
        return;
    }
    
    NSMutableArray<MPSegment *> *segments = nil;
    BOOL success = NO;
    
    NSArray *segmentsList = nil;
    NSInteger responseCode = [httpResponse statusCode];
    success = (responseCode == HTTPStatusCodeSuccess || responseCode == HTTPStatusCodeAccepted) && [data length] > 0;
    
    if (success) {
        NSError *serializationError = nil;
        NSDictionary *segmentsDictionary = nil;
        
        @try {
            segmentsDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&serializationError];
            success = serializationError == nil;
        } @catch (NSException *exception) {
            segmentsDictionary = nil;
            success = NO;
            MPILogError(@"Segments Error: %@", [exception reason]);
        }
        
        if (success) {
            segmentsList = segmentsDictionary[kMPSegmentListKey];
        }
        
        if (segmentsList.count > 0) {
            segments = [[NSMutableArray alloc] initWithCapacity:segmentsList.count];
            MPSegment *segment;
            
            for (NSDictionary *segmentDictionary in segmentsList) {
                segment = [[MPSegment alloc] initWithDictionary:segmentDictionary];
                
                if (segment) {
                    [segments addObject:segment];
                }
            }
        }
        
        MPILogVerbose(@"Segments Response Code: %ld", (long)responseCode);
    } else {
        MPILogWarning(@"Segments Error - Response Code: %ld", (long)responseCode);
    }
    
    if (segments.count == 0) {
        segments = nil;
    }
    
    NSError *segmentError = nil;
    if (responseCode == HTTPStatusCodeForbidden) {
        segmentError = [NSError errorWithDomain:@"mParticle Segments"
                                           code:responseCode
                                       userInfo:@{@"message":@"Segments not enabled for this org."}];
    }
    
    if (elapsedTime < timeout) {
        completionHandler(success, (NSArray *)segments, elapsedTime, segmentError);
    } else {
        segmentError = [NSError errorWithDomain:@"mParticle Segments"
                                           code:MPNetworkErrorDelayedSegments
                                       userInfo:@{@"message":@"It took too long to retrieve segments."}];
        
        completionHandler(success, (NSArray *)segments, elapsedTime, segmentError);
    }
}

- (void)upload:(NSArray<MPUpload *> *)uploads index:(NSUInteger)index completionHandler:(MPUploadsCompletionHandler)completionHandler {
    __weak MPNetworkCommunication *weakSelf = self;
    
    __block UIBackgroundTaskIdentifier backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    
    if (![MPStateMachine isAppExtension]) {
        backgroundTaskIdentifier = [[MPApplication sharedUIApplication] beginBackgroundTaskWithExpirationHandler:^{
            if (backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
                [[MPApplication sharedUIApplication] endBackgroundTask:backgroundTaskIdentifier];
                backgroundTaskIdentifier = UIBackgroundTaskInvalid;
            }
        }];
    }
    
    MPUpload *upload = uploads[index];
    NSString *uploadString = [upload serializedString];
    MPConnector *connector = [[MPConnector alloc] init];
    NSString *const connectionId = [[NSUUID UUID] UUIDString];
    connector.connectionId = connectionId;
    
    MPILogVerbose(@"Source Batch Id: %@", upload.uuid);
    NSTimeInterval start = [[NSDate date] timeIntervalSince1970];
    
    NSData *zipUploadData = nil;
    std::tuple<unsigned char *, unsigned int> zipData = mParticle::Zip::compress((const unsigned char *)[upload.uploadData bytes], (unsigned int)[upload.uploadData length]);
    if (get<0>(zipData) != nullptr) {
        zipUploadData = [[NSData alloc] initWithBytes:get<0>(zipData) length:get<1>(zipData)];
        delete [] get<0>(zipData);
    } else {
        [self processNetworkResponseAction:MPNetworkResponseActionDeleteBatch batchObject:upload];
        completionHandler(NO, upload, nil, YES);
        return;
    }
    
    MPConnectorResponse *response = [connector responseFromPostRequestToURL:self.eventURL
                                                                    message:uploadString
                                                           serializedParams:zipUploadData];
    NSData *data = response.data;
    NSHTTPURLResponse *httpResponse = response.httpResponse;
    
    __strong MPNetworkCommunication *strongSelf = weakSelf;
    
    if (!strongSelf) {
        completionHandler(NO, upload, nil, YES);
        return;
    }
    
    if (![MPStateMachine isAppExtension]) {
        if (backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
            [[MPApplication sharedUIApplication] endBackgroundTask:backgroundTaskIdentifier];
            backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        }
    }
    
    NSDictionary *responseDictionary = nil;
    MPNetworkResponseAction responseAction = MPNetworkResponseActionNone;
    BOOL finished = index == uploads.count - 1;
    NSInteger responseCode = [httpResponse statusCode];
    BOOL success = responseCode == HTTPStatusCodeSuccess || responseCode == HTTPStatusCodeAccepted;
    
    if (!data && success) {
        completionHandler(NO, upload, nil, finished);
        return;
    }
    
    success = success && [data length] > 0;
    if (success) {
        NSError *serializationError = nil;
        
        @try {
            responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&serializationError];
            success = serializationError == nil && [responseDictionary[kMPMessageTypeKey] isEqualToString:kMPMessageTypeResponseHeader];
            MPILogVerbose(@"Uploaded Message: %@\n", uploadString);
            MPILogVerbose(@"Upload Response Code: %ld", (long)responseCode);
        } @catch (NSException *exception) {
            responseDictionary = nil;
            success = NO;
            MPILogError(@"Uploads Error: %@", [exception reason]);
        }
    } else {
        if (responseCode == HTTPStatusCodeBadRequest) {
            responseAction = MPNetworkResponseActionDeleteBatch;
        } else if (responseCode == HTTPStatusCodeServiceUnavailable || responseCode == HTTPStatusCodeTooManyRequests) {
            responseAction = MPNetworkResponseActionThrottle;
        }
        
        MPILogWarning(@"Uploads Error - Response Code: %ld", (long)responseCode);
    }
    
    MPILogVerbose(@"Upload Execution Time: %.2fms", ([[NSDate date] timeIntervalSince1970] - start) * 1000.0);
    
    [strongSelf processNetworkResponseAction:responseAction batchObject:upload httpResponse:httpResponse];
    
    completionHandler(success, upload, responseDictionary, finished);
    
    if (!finished) {
        [strongSelf upload:uploads index:(index + 1) completionHandler:completionHandler];
    }
}

- (void)identityApiRequestWithURL:(NSURL*)url identityRequest:(MPIdentityHTTPBaseRequest *_Nonnull)identityRequest blockOtherRequests: (BOOL) blockOtherRequests completion:(nullable MPIdentityApiManagerCallback)completion {
    
    if (self.identifying) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:mParticleIdentityErrorDomain code:MPIdentityErrorResponseCodeRequestInProgress userInfo:@{mParticleIdentityErrorKey:@"Identity API request in progress."}]);
        }
        return;
    }
    
    if ([MParticle sharedInstance].stateMachine.optOut) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:mParticleIdentityErrorDomain code:MPIdentityErrorResponseCodeOptOut userInfo:@{mParticleIdentityErrorKey:@"Opt Out Enabled."}]);
        }
        return;
    }
    
    if (blockOtherRequests) {
        self.identifying = YES;
    }
    __weak MPNetworkCommunication *weakSelf = self;
    
    __block UIBackgroundTaskIdentifier backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    
    if (![MPStateMachine isAppExtension]) {
        backgroundTaskIdentifier = [[MPApplication sharedUIApplication] beginBackgroundTaskWithExpirationHandler:^{
            if (backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
                __strong MPNetworkCommunication *strongSelf = weakSelf;
                if (strongSelf) {
                    strongSelf.identifying = NO;
                }
                
                [[MPApplication sharedUIApplication] endBackgroundTask:backgroundTaskIdentifier];
                backgroundTaskIdentifier = UIBackgroundTaskInvalid;
            }
        }];
    }
    
    MPConnector *connector = [[MPConnector alloc] init];
    NSString *const connectionId = [[NSUUID UUID] UUIDString];
    connector.connectionId = connectionId;
    
    NSTimeInterval start = [[NSDate date] timeIntervalSince1970];
    
    NSDictionary *dictionary = [identityRequest dictionaryRepresentation];
    NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:nil];
    NSString *jsonRequest = [[NSString alloc] initWithData:data
                                                  encoding:NSUTF8StringEncoding];
    
    MPILogVerbose(@"Identity request:\nURL: %@ \nBody:%@", url, jsonRequest);
    
    MPConnectorResponse *response = [connector responseFromPostRequestToURL:url
                                                                    message:nil
                                                           serializedParams:data];
    NSData *responseData = response.data;
    NSError *error = response.error;
    NSHTTPURLResponse *httpResponse = response.httpResponse;
    
    __strong MPNetworkCommunication *strongSelf = weakSelf;
    
    if (!strongSelf) {
        if (completion) {
            MPIdentityHTTPErrorResponse *errorResponse = [[MPIdentityHTTPErrorResponse alloc] initWithJsonObject:nil httpCode:0];
            completion(nil, [NSError errorWithDomain:mParticleIdentityErrorDomain code:MPIdentityErrorResponseCodeUnknown userInfo:@{mParticleIdentityErrorKey:errorResponse}]);
        }
        
        return;
    }
    
    if (![MPStateMachine isAppExtension]) {
        if (backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
            [[MPApplication sharedUIApplication] endBackgroundTask:backgroundTaskIdentifier];
            backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        }
    }
    
    NSDictionary *responseDictionary = nil;
    NSString *responseString = nil;
    NSInteger responseCode = [httpResponse statusCode];
    BOOL success = responseCode == HTTPStatusCodeSuccess || responseCode == HTTPStatusCodeAccepted;
    
    success = success && [responseData length] > 0;
    
    NSError *serializationError = nil;
    
    MPILogVerbose(@"Identity response code: %ld", (long)responseCode);
    
    if (success) {
        @try {
            responseString = [[NSString alloc] initWithData:responseData
                                                   encoding:NSUTF8StringEncoding];
            responseDictionary = [NSJSONSerialization JSONObjectWithData:responseData
                                                                 options:0
                                                                   error:&serializationError];
        } @catch (NSException *exception) {
            responseDictionary = nil;
            success = NO;
            MPILogError(@"Identity response serialization error: %@", [exception reason]);
        }
    }
    
    MPILogVerbose(@"Identity execution time: %.2fms", ([[NSDate date] timeIntervalSince1970] - start) * 1000.0);
    
    strongSelf.identifying = NO;
    
    if (success) {
        if (responseString) {
            MPILogVerbose(@"Identity response:\n%@", responseString);
        }
        BOOL isModify = [identityRequest isMemberOfClass:[MPIdentityHTTPModifyRequest class]];
        if (isModify) {
            if (completion) {
                completion([[MPIdentityHTTPModifySuccessResponse alloc] init], nil);
            }
        } else {
            MPIdentityHTTPSuccessResponse *response = [[MPIdentityHTTPSuccessResponse alloc] initWithJsonObject:responseDictionary];
            _context = response.context;
            if (completion) {
                completion(response, nil);
            }
        }
    } else {
        if (completion) {
            MPIdentityHTTPErrorResponse *errorResponse;
            if (error) {
                if (error.code == MPConnectivityErrorCodeNoConnection) {
                    errorResponse = [[MPIdentityHTTPErrorResponse alloc] initWithCode:MPIdentityErrorResponseCodeClientNoConnection message:@"Device has no network connectivity." error:error];
                } else if ([error.domain isEqualToString: NSURLErrorDomain] ){
                    errorResponse = [[MPIdentityHTTPErrorResponse alloc] initWithCode:MPIdentityErrorResponseCodeSSLError message:@"Failed to establish SSL connection." error:error];
                } else {
                    errorResponse = [[MPIdentityHTTPErrorResponse alloc] initWithCode:MPIdentityErrorResponseCodeUnknown message:@"An unknown client-side error has occured" error:error];
                }
            } else {
                errorResponse = [[MPIdentityHTTPErrorResponse alloc] initWithJsonObject:responseDictionary httpCode:responseCode];
            }
            completion(nil, [NSError errorWithDomain:mParticleIdentityErrorDomain code:errorResponse.code userInfo:@{mParticleIdentityErrorKey:errorResponse}]);
        }
    }
}

- (void)identify:(MPIdentityApiRequest *_Nonnull)identifyRequest completion:(nullable MPIdentityApiManagerCallback)completion {
    MPIdentifyHTTPRequest *request = [[MPIdentifyHTTPRequest alloc] initWithIdentityApiRequest:identifyRequest];
    [self identityApiRequestWithURL:self.identifyURL identityRequest:request blockOtherRequests: YES completion:completion];
}

- (void)login:(MPIdentityApiRequest *_Nullable)loginRequest completion:(nullable MPIdentityApiManagerCallback)completion {
    MPIdentifyHTTPRequest *request = [[MPIdentifyHTTPRequest alloc] initWithIdentityApiRequest:loginRequest];
    [self identityApiRequestWithURL:self.loginURL identityRequest:request blockOtherRequests: YES completion:completion];
}

- (void)logout:(MPIdentityApiRequest *_Nullable)logoutRequest completion:(nullable
                                                                          MPIdentityApiManagerCallback)completion {
    MPIdentifyHTTPRequest *request = [[MPIdentifyHTTPRequest alloc] initWithIdentityApiRequest:logoutRequest];
    [self identityApiRequestWithURL:self.logoutURL identityRequest:request blockOtherRequests: YES completion:completion];
}

- (void)modify:(MPIdentityApiRequest *_Nonnull)modifyRequest completion:(nullable MPIdentityApiManagerModifyCallback)completion {
    
    NSMutableArray *identityChanges = [NSMutableArray array];
    
    NSDictionary *identitiesDictionary = modifyRequest.userIdentities;
    NSDictionary *existingIdentities = [MParticle sharedInstance].identity.currentUser.userIdentities;
    
    [identitiesDictionary enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull identityType, NSString *value, BOOL * _Nonnull stop) {
        NSString *oldValue = existingIdentities[identityType];
        
        if ((NSNull *)value == [NSNull null]) {
            value = nil;
        }

        if (!oldValue || ![value isEqualToString:oldValue]) {
            MPUserIdentity userIdentity = (MPUserIdentity)[identityType intValue];
            NSString *stringType = [MPIdentityHTTPIdentities stringForIdentityType:userIdentity];
            MPIdentityHTTPIdentityChange *identityChange = [[MPIdentityHTTPIdentityChange alloc] initWithOldValue:oldValue value:value identityType:stringType];
            [identityChanges addObject:identityChange];
        }
    }];
    
    [self modifyWithIdentityChanges:identityChanges blockOtherRequests:YES completion:completion];
    
}

- (void)modifyDeviceID:(NSString *_Nonnull)deviceIdType value:(NSString *_Nonnull)value oldValue:(NSString *_Nonnull)oldValue {
    NSMutableArray *identityChanges = [NSMutableArray array];
    MPIdentityHTTPIdentityChange *identityChange = [[MPIdentityHTTPIdentityChange alloc] initWithOldValue:oldValue value:value identityType:deviceIdType];
    [identityChanges addObject:identityChange];
    [self modifyWithIdentityChanges:identityChanges blockOtherRequests:NO completion:nil];
}

- (void)modifyWithIdentityChanges:(NSArray *)identityChanges blockOtherRequests:(BOOL)blockOtherRequests completion:(nullable MPIdentityApiManagerModifyCallback)completion {
    
    if (identityChanges == nil || identityChanges.count == 0) {
        if (completion) {
            completion([[MPIdentityHTTPModifySuccessResponse alloc] init], nil);
        }
        return;
    }
    
    NSString *mpid = [MPPersistenceController mpId].stringValue;
    MPIdentityHTTPModifyRequest *request = [[MPIdentityHTTPModifyRequest alloc] initWithMPID:mpid identityChanges:[identityChanges copy]];
    
    [self identityApiRequestWithURL:self.modifyURL identityRequest:request blockOtherRequests:blockOtherRequests completion:^(MPIdentityHTTPBaseSuccessResponse * _Nullable httpResponse, NSError * _Nullable error) {
        if (completion) {
            completion((MPIdentityHTTPModifySuccessResponse *)httpResponse, error);
        }
    }];
}

@end
