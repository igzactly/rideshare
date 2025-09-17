import 'package:flutter/material.dart';
import '../utils/theme.dart';

class NotificationBanner extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;
  final Duration duration;

  const NotificationBanner({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    this.onTap,
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<NotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();

    // Auto-dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 100),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () {
                    widget.onTap?.call();
                    _dismiss();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: widget.iconColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.iconColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.message,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _dismiss,
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class NotificationOverlay {
  static void showRideAccepted({
    required BuildContext context,
    required String driverName,
    required String pickupAddress,
    required String dropoffAddress,
  }) {
    _showNotification(
      context: context,
      title: 'Ride Accepted! 🚗',
      message: 'Driver $driverName has accepted your ride from $pickupAddress to $dropoffAddress',
      icon: Icons.check_circle,
      backgroundColor: AppTheme.successColor,
      iconColor: Colors.white,
    );
  }

  static void showRideStarted({
    required BuildContext context,
    required String driverName,
  }) {
    _showNotification(
      context: context,
      title: 'Ride Started! 🚀',
      message: 'Driver $driverName has started your ride. You can now track their live location.',
      icon: Icons.play_circle,
      backgroundColor: AppTheme.primaryPurple,
      iconColor: Colors.white,
    );
  }

  static void showRideCompleted({
    required BuildContext context,
    required String driverName,
  }) {
    _showNotification(
      context: context,
      title: 'Ride Completed! ✅',
      message: 'Your ride with $driverName has been completed. Please provide feedback and payment.',
      icon: Icons.done_all,
      backgroundColor: AppTheme.successColor,
      iconColor: Colors.white,
    );
  }

  static void showRideRequest({
    required BuildContext context,
    required String passengerName,
    required String pickupAddress,
    required String dropoffAddress,
  }) {
    _showNotification(
      context: context,
      title: 'New Ride Request! 📱',
      message: '$passengerName wants to join your ride from $pickupAddress to $dropoffAddress',
      icon: Icons.person_add,
      backgroundColor: AppTheme.primaryOrange,
      iconColor: Colors.white,
    );
  }

  static void _showNotification({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) => NotificationBanner(
        title: title,
        message: message,
        icon: icon,
        backgroundColor: backgroundColor,
        iconColor: iconColor,
      ),
    );
  }
}
