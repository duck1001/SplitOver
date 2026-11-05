//
//  SODiagnostics.h
//  SplitOver
//

#import <Foundation/Foundation.h>

static inline void SOHostLog(NSString *message) {
    NSLog(@"[SplitOver] %@", message);
}
