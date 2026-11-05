#pragma once
#include <math.h>

// More logical app points per visible window point for small unlocked windows.
// Use ONE multiplier on both axes so density changes cannot stretch content.
static inline double DPDenseCanvasMultiplier(double width, double height, double referenceWidth) {
    if (width < 1 || height < 1) return 1.0;
    return fmax(1.0, fmax(referenceWidth / width, 320.0 / height));
}

// Keep the APP content proportional; the title bar has a fixed height.
static inline double DPAspectWidth(double requested, double ratio, double maxWidth,
                                    double maxHeight, double titleHeight) {
    double upper = fmax(1.0, fmin(maxWidth, fmax(1.0, maxHeight - titleHeight) * ratio));
    double lower = fmin(upper, fmax(180.0, (220.0 - titleHeight) * ratio));
    return fmin(upper, fmax(lower, requested));
}

// Project a diagonal drag onto the aspect-locked resize direction.
static inline double DPAspectDragWidth(double startWidth, double ratio, double dx, double dy) {
    return startWidth + (dx + dy / ratio) / (1.0 + 1.0 / (ratio * ratio));
}

static inline double DPReferenceCanvasScale(double width, double height,
                                            double targetWidth, double targetHeight,
                                            int landscape) {
    double presentedWidth = landscape ? height : width;
    double presentedHeight = landscape ? width : height;
    return fmin(targetWidth / presentedWidth, targetHeight / presentedHeight);
}
