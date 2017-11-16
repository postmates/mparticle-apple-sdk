#import "MPSession.h"
#import "MPIConstants.h"
#import "MPPersistenceController.h"

NSString *const sessionNumberFileName = @"SessionNumber";
NSString *const sessionUUIDKey = @"sessionId";
NSString *const sessionNumberKey = @"sessionNumber";

@implementation MPSession

@synthesize sessionNumber = _sessionNumber;

- (instancetype)init {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    return [self initWithSessionId:0 UUID:[[NSUUID UUID] UUIDString] backgroundTime:0.0 startTime:now endTime:now attributes:nil sessionNumber:nil numberOfInterruptions:0 eventCounter:0 suspendTime:0 userId:[MPPersistenceController mpId] sessionUserIds:[[MPPersistenceController mpId] stringValue]];
}

- (instancetype)initWithStartTime:(NSTimeInterval)timestamp userId:(NSNumber *)userId {
    self = [self initWithSessionId:0 UUID:[[NSUUID UUID] UUIDString] backgroundTime:0.0 startTime:timestamp endTime:timestamp attributes:nil sessionNumber:nil numberOfInterruptions:0 eventCounter:0 suspendTime:0 userId:userId sessionUserIds:[userId stringValue]];
    
    return self;
}

- (instancetype)initWithSessionId:(int64_t)sessionId
                             UUID:(NSString *)uuid
                   backgroundTime:(NSTimeInterval)backgroundTime
                        startTime:(NSTimeInterval)startTime
                          endTime:(NSTimeInterval)endTime
                       attributes:(NSMutableDictionary *)attributesDictionary
                    sessionNumber:(NSNumber *)sessionNumber
            numberOfInterruptions:(uint)numberOfInterruptions
                     eventCounter:(uint)eventCounter
                      suspendTime:(NSTimeInterval)suspendTime
                           userId:(NSNumber *)userId
                   sessionUserIds:(NSString *)sessionUserIds
{
    self = [super init];
    if (!self) {
        return nil;
    }
    
    _sessionId = sessionId;
    _uuid = uuid;
    _backgroundTime = backgroundTime;
    _startTime = startTime;
    _endTime = endTime;
    _length = _endTime - _startTime;
    _eventCounter = eventCounter;
    _persisted = sessionId != 0;
    _numberOfInterruptions = numberOfInterruptions;
    _suspendTime = suspendTime;
    _sessionUserIds = sessionUserIds;
    
    _attributesDictionary = attributesDictionary != nil ? attributesDictionary : [[NSMutableDictionary alloc] init];
    
    _sessionNumber = sessionNumber != nil ? sessionNumber : [self sessionNumber];
    _userId = userId;

    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Session\n Id: %lld\n UUID: %@\n Background time: %.0f\n Start: %.0f\n End: %.0f\n Length: %.0f\n EventCounter: %d\n Persisted: %d\n Attributes: %@\n Interruptions: %d\n", self.sessionId, self.uuid, self.backgroundTime, self.startTime, self.endTime, self.length, self.eventCounter, self.persisted, self.attributesDictionary, self.numberOfInterruptions];
}

- (BOOL)isEqual:(MPSession *)object {
    if (MPIsNull(object) || ![object isKindOfClass:[MPSession class]]) {
        return NO;
    }
    
    BOOL isEqual = _sessionId == object.sessionId &&
                   _eventCounter == object.eventCounter &&
                   [_uuid isEqualToString:object.uuid] &&
                   [_sessionNumber isEqualToNumber:object.sessionNumber];
    
    return isEqual;
}

#pragma mark NSCopying
- (id)copyWithZone:(NSZone *)zone {
    MPSession *copyObject = [[MPSession alloc] initWithSessionId:_sessionId
                                                            UUID:[_uuid copy]
                                                  backgroundTime:_backgroundTime
                                                       startTime:_startTime
                                                         endTime:_endTime
                                                      attributes:[_attributesDictionary mutableCopy]
                                                   sessionNumber:[_sessionNumber copy]
                                           numberOfInterruptions:_numberOfInterruptions
                                                    eventCounter:_eventCounter
                                                     suspendTime:_suspendTime
                                                          userId:_userId
                                                  sessionUserIds:_sessionUserIds];
    
    return copyObject;
}

#pragma mark Public accessors
- (NSTimeInterval)foregroundTime {
    return _length - _backgroundTime;
}

- (void)setEndTime:(NSTimeInterval)endTime {
    if (endTime > _startTime) {
        _endTime = endTime;
        _length = _endTime - _startTime;
    } else if (_length > 0) {
        _endTime = _startTime + _length;
    } else {
        _endTime = _startTime;
    }
}

- (NSTimeInterval)length {
    if (_length == 0 && _endTime > _startTime) {
        [self willChangeValueForKey:@"length"];
        _length = _endTime - _startTime;
        [self didChangeValueForKey:@"length"];
    }
    
    return _length;
}

- (void)setSessionId:(int64_t)sessionId {
    _sessionId = sessionId;
    _persisted = sessionId != 0;
}

- (NSNumber *)sessionNumber {
    if (_sessionNumber != nil) {
        return _sessionNumber;
    }
    
    NSString *documentsDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *sessionNumberPath = [documentsDirectory stringByAppendingPathComponent:sessionNumberFileName];
    NSDictionary *sessionNumberDictionary;
    NSUInteger sessionNumber = 0;
    
    if ([fileManager fileExistsAtPath:sessionNumberPath]) {
        sessionNumberDictionary = [NSDictionary dictionaryWithContentsOfFile:sessionNumberPath];
        if (sessionNumberDictionary) {
            NSString *uuid = sessionNumberDictionary[sessionUUIDKey];
            sessionNumber = [sessionNumberDictionary[sessionNumberKey] integerValue];
            
            if (![uuid isEqualToString:self.uuid]) {
                ++sessionNumber;
            }
            
            if (sessionNumber >= (INT_MAX >> 1)) {
                sessionNumber = 0;
            }
        }
        
        [fileManager removeItemAtPath:sessionNumberPath error:nil];
    }
    
    [self willChangeValueForKey:@"sessionNumber"];
    _sessionNumber = @(sessionNumber);
    [self didChangeValueForKey:@"sessionNumber"];
    
    sessionNumberDictionary = @{sessionUUIDKey:self.uuid, sessionNumberKey:_sessionNumber};
    [sessionNumberDictionary writeToFile:sessionNumberPath atomically:YES];
    
    return _sessionNumber;
}

#pragma mark Public methods
- (void)incrementCounter {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    [self willChangeValueForKey:@"eventCounter"];
    ++_eventCounter;
    [self didChangeValueForKey:@"eventCounter"];
    
    if (_eventCounter > EVENT_LIMIT) {
        [notificationCenter postNotificationName:kMPEventCounterLimitReachedNotification object:self userInfo:nil];
    }
}

- (void)suspendSession {
    [self willChangeValueForKey:@"numberOfInterruptions"];
    [self willChangeValueForKey:@"suspendTime"];

    ++_numberOfInterruptions;
    _suspendTime = [[NSDate date] timeIntervalSince1970];
    
    [self didChangeValueForKey:@"numberOfInterruptions"];
    [self didChangeValueForKey:@"suspendTime"];
}

@end
