#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "AWSLex.h"
#import "AWSLexInteractionKit.h"
#import "AWSLexModel+Extensions.h"
#import "AWSLexModel.h"
#import "AWSLexRequestRetryHandler.h"
#import "AWSLexResources.h"
#import "AWSLexService.h"
#import "AWSLexSignature.h"
#import "AWSLexVoiceButton.h"

FOUNDATION_EXPORT double AWSLexVersionNumber;
FOUNDATION_EXPORT const unsigned char AWSLexVersionString[];

