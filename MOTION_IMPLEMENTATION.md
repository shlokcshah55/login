# Bottom Navigation Motion Implementation

## Overview

This implementation adds sophisticated motion functionality to hide and show the bottom navigation bar based on user interactions, as requested.

## Features Implemented

### 1. Bottom Navigation Visibility Provider (`bottom_nav_visibility_provider.dart`)

A new provider that manages the visibility state of the bottom navigation bar with the following capabilities:

- **State Management**: Tracks visibility status (`isVisible`)
- **Auto-hide Timer**: Automatically hides the bottom nav after 2 seconds when shown temporarily
- **Control Methods**:
  - `hide()`: Immediately hides the bottom nav
  - `show()`: Immediately shows the bottom nav
  - `showTemporarily()`: Shows the bottom nav and auto-hides after delay
  - `toggle()`: Toggles visibility state

### 2. Main Screen Animation (`main.dart`)

Enhanced the `MainScreen` with smooth animations:

- **SlideTransition**: Bottom navigation slides down/up with smooth motion
- **FadeTransition**: Opacity animation for subtle appearance/disappearance
- **AnimatedContainer**: Dynamic elevation and shadow effects
- **Animation Controllers**: Proper lifecycle management with `TickerProviderStateMixin`

### 3. Motion Triggers - Home Page (`home_page.dart`)

#### Hide Triggers:
- **Carousel Scrolling**: Uses `NotificationListener<ScrollNotification>` to detect when user starts scrolling through location cards
- **Horizontal Swipe Detection**: Automatically hides bottom nav when user interacts with the carousel

#### Show Triggers:
- **Map Tap**: Tap anywhere on the map (outside carousel) shows bottom nav temporarily
- **Vertical Edge Swipe**: Swipe up from bottom edge (85% of screen height) with significant upward movement shows bottom nav temporarily

### 4. Carousel Integration (`location_carousel.dart`)

- **Page Change Detection**: Automatically hides bottom nav when user swipes between location cards
- **Provider Integration**: Uses `BottomNavVisibilityProvider` for state management

## Motion Style Details

### Animation Specifications:
- **Duration**: 300ms for all transitions
- **Curve**: `Curves.easeInOut` for natural motion feel
- **Slide Direction**: Bottom nav slides from `Offset(0, 1)` to `Offset.zero`
- **Fade Range**: Opacity transitions from `0.0` to `1.0`
- **Shadow Animation**: Dynamic shadow blur (5-15) and offset (2-6) based on visibility

## Integration Points

The implementation integrates seamlessly with the existing codebase:

- **Provider Pattern**: Uses the existing Provider architecture
- **No Breaking Changes**: All existing functionality remains intact
- **Performance Optimized**: Animations are hardware-accelerated
- **Memory Safe**: Proper disposal of animation controllers

## Usage

The functionality works automatically once implemented:

1. **To Hide**: Scroll carousel horizontally or start any carousel interaction
2. **To Show**: Tap map or swipe up from bottom edge

This implementation provides the exact motion behavior requested while maintaining the app's existing design patterns and performance characteristics.
