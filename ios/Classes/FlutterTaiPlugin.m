#import "FlutterTaiPlugin.h"
#import <TAISDK/TAIOralEvaluation.h>
#import <objc/runtime.h>

@interface FlutterTaiPlugin () <TAIOralEvaluationDelegate>
@property (strong, nonatomic) TAIOralEvaluation *oralEvaluation;
@property (strong, nonatomic) NSString *fileName;

@end
@implementation FlutterTaiPlugin
FlutterMethodChannel *flutterTaiPluginChannel;
NSString *flutterTaiPluginId;

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
   flutterTaiPluginChannel = [FlutterMethodChannel
      methodChannelWithName:@"flutter_tai"
            binaryMessenger:[registrar messenger]];
  FlutterTaiPlugin* instance = [[FlutterTaiPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:flutterTaiPluginChannel];
}
- (TAIOralEvaluation *)oralEvaluation
{
    if(!_oralEvaluation){
        _oralEvaluation = [[TAIOralEvaluation alloc] init];
        _oralEvaluation.delegate = self;
    }
    return _oralEvaluation;
}
- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"record" isEqualToString:call.method]) {
    [self onRecord:call result:result];
  } else if ([@"stop" isEqualToString:call.method]) {
    [self onStop:call result:result];
  } else {
    result(FlutterMethodNotImplemented);
  }
}
- (IBAction)onStop:(FlutterMethodCall*)call result:(FlutterResult)result{
    flutterTaiPluginId =call.arguments[@"id"];
    if([self.oralEvaluation isRecording]){
        [self.oralEvaluation stopRecordAndEvaluation:^(TAIError *error) {
            [flutterTaiPluginChannel invokeMethod:@"onStop" arguments:@{
                                                                        @"err": [NSString stringWithFormat:@"%@", error],
                                                                        @"id":flutterTaiPluginId
                                                                        }];
        }];
        return;
    }
}
- (IBAction)onRecord:(FlutterMethodCall*)call result:(FlutterResult)result{
    flutterTaiPluginId =call.arguments[@"id"];
    if([self.oralEvaluation isRecording]){
        [self.oralEvaluation stopRecordAndEvaluation:^(TAIError *error) {
            [flutterTaiPluginChannel invokeMethod:@"onStop" arguments:@{
                                                                        @"err": [NSString stringWithFormat:@"%@", error],
                                                                        @"id":flutterTaiPluginId
                                                                        }];
        }];
        return;
    }else{
    _fileName = [NSString stringWithFormat:@"taisdk_%ld.mp3", (long)[[NSDate date] timeIntervalSince1970]];
    
    
    TAIOralEvaluationParam *param = [[TAIOralEvaluationParam alloc] init];
    param.sessionId = [[NSUUID UUID] UUIDString];
    param.appId = call.arguments[@"appId"];
    
    param.soeAppId = call.arguments[@"soeAppId"];
    param.secretId = call.arguments[@"secretId"];
    param.secretKey = call.arguments[@"secretKey"];
    param.token = call.arguments[@"token"];
    param.workMode = [call.arguments[@"workMode"] intValue];
    param.evalMode = [call.arguments[@"evalMode"] intValue];
    param.serverType = [call.arguments[@"serverType"] intValue];
    
    param.fileType = TAIOralEvaluationFileType_Mp3;
    param.storageMode = [call.arguments[@"storageMode"] intValue];
    param.textMode = [call.arguments[@"textMode"] intValue];
    param.scoreCoeff = [call.arguments[@"scoreCoeff"] intValue];
    param.refText = call.arguments[@"refText"];
    if(param.workMode == TAIOralEvaluationWorkMode_Stream){
        param.timeout = (NSInteger)call.arguments[@"timeout"];
        param.retryTimes = (NSInteger)call.arguments[@"retryTimes"];
    }
    else{
        param.timeout = (NSInteger)call.arguments[@"timeout"];
        param.retryTimes = (NSInteger)call.arguments[@"retryTimes"];
    }
    TAIRecorderParam *recordParam = [[TAIRecorderParam alloc] init];
    recordParam.fragEnable = [call.arguments[@"fragEnable"] boolValue];
    recordParam.fragSize = [call.arguments[@"fragSize"] intValue];
    recordParam.vadEnable =[call.arguments[@"vadEnable"] boolValue];
    recordParam.vadInterval = [call.arguments[@"vadInterval"] intValue];
    [self.oralEvaluation setRecorderParam:recordParam];
    [self.oralEvaluation startRecordAndEvaluation:param callback:^(TAIError *error) {
        [flutterTaiPluginChannel invokeMethod:@"onResult" arguments:@{@"id":flutterTaiPluginId,@"err":[NSString stringWithFormat:@"%@", error]}];
    }];
    }
}
#pragma mark - oral evaluation delegate
- (void)oralEvaluation:(TAIOralEvaluation *)oralEvaluation onEvaluateData:(TAIOralEvaluationData *)data result:(TAIOralEvaluationRet *)result error:(TAIError *)error
{
    [self writeMP3Data:data.audio fileName:_fileName];
    if(result!=nil){
        NSDictionary *dic=[self getDictionaryFromObject_Ext:result];
    NSData * jsonData=[NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:nil];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [flutterTaiPluginChannel invokeMethod:@"onEvaluationData" arguments:@{@"id":flutterTaiPluginId,@"seqId":[NSString stringWithFormat:@"%ld", (long)data.seqId],@"end":[NSString stringWithFormat:@"%ld", (long)data.bEnd], @"err":[NSString stringWithFormat:@"%@", error],@"ret":jsonString}];
    }
}
- (NSDictionary*)getDictionaryFromObject_Ext:(id)obj
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    unsigned int propsCount;
    objc_property_t *props = class_copyPropertyList([obj class], &propsCount);
    for(int i = 0;i < propsCount; i++) {
        objc_property_t prop = props[i];
        id value = nil;
        
        @try {
            NSString *propName = [NSString stringWithUTF8String:property_getName(prop)];
            value = [self getObjectInternal_Ext:[obj valueForKey:propName]];
            if(value != nil) {
                [dic setObject:value forKey:propName];
            }
        }
        @catch (NSException *exception) {
            //[self logError:exception];
            NSLog(@"%@",exception);
        }
        
    }
    free(props);
    return dic;
}
- (id)getObjectInternal_Ext:(id)obj
{
    if(!obj
       || [obj isKindOfClass:[NSString class]]
       || [obj isKindOfClass:[NSNumber class]]
       || [obj isKindOfClass:[NSNull class]]) {
        return obj;
    }
    
    if([obj isKindOfClass:[NSArray class]]) {
        NSArray *objarr = obj;
        NSMutableArray *arr = [NSMutableArray arrayWithCapacity:objarr.count];
        for(int i = 0;i < objarr.count; i++) {
            [arr setObject:[self getObjectInternal_Ext:[objarr objectAtIndex:i]] atIndexedSubscript:i];
        }
        return arr;
    }
    
    if([obj isKindOfClass:[NSDictionary class]]) {
        NSDictionary *objdic = obj;
        NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithCapacity:[objdic count]];
        for(NSString *key in objdic.allKeys) {
            [dic setObject:[self getObjectInternal_Ext:[objdic objectForKey:key]] forKey:key];
        }
        return dic;
    }
    return [self getDictionaryFromObject_Ext:obj];
}
- (void)onEndOfSpeechInOralEvaluation:(TAIOralEvaluation *)oralEvaluation
{
}

- (void)oralEvaluation:(TAIOralEvaluation *)oralEvaluation onVolumeChanged:(NSInteger)volume
{
    [flutterTaiPluginChannel invokeMethod:@"onProgress" arguments:@{@"id":flutterTaiPluginId,@"volume": [NSString stringWithFormat:@"%ld",volume]}];
}
- (void)writeMP3Data:(NSData *)data fileName:(NSString *)fileName
{
    NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *mp3Path = [path stringByAppendingPathComponent:fileName];
    if([[NSFileManager defaultManager] fileExistsAtPath:mp3Path] == false){
        [[NSFileManager defaultManager] createFileAtPath:mp3Path contents:nil attributes:nil];
    }
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:mp3Path];
    [handle seekToEndOfFile];
    [handle writeData:data];
}
@end
