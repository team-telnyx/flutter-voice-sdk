import 'dart:math';
import 'package:flutter/material.dart';

class AudioWaveform extends StatelessWidget {
  final String label;
  final List<double> audioLevels;
  final Color color;
  final double height;
  final double minBarHeight;
  final double maxBarHeight;

  const AudioWaveform({
    super.key,
    required this.label,
    required this.audioLevels,
    this.color = Colors.blue,
    this.height = 60,
    this.minBarHeight = 2.0,
    this.maxBarHeight = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                audioLevels.isNotEmpty
                    ? '${(audioLevels.last * 100).toStringAsFixed(0)}%'
                    : '0%',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: height,
            child: audioLevels.isNotEmpty
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: audioLevels.asMap().entries.map((entry) {
                      final level = entry.value.clamp(0.0, 1.0);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0.5),
                          child: AnimatedWaveformBar(
                            level: level,
                            color: color,
                            minHeight: minBarHeight,
                            maxHeight: min(maxBarHeight, height),
                          ),
                        ),
                      );
                    }).toList(),
                  )
                : Container(
                    width: double.infinity,
                    height: minBarHeight,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class AnimatedWaveformBar extends StatefulWidget {
  final double level;
  final Color color;
  final double minHeight;
  final double maxHeight;

  const AnimatedWaveformBar({
    super.key,
    required this.level,
    required this.color,
    required this.minHeight,
    required this.maxHeight,
  });

  @override
  State<AnimatedWaveformBar> createState() => _AnimatedWaveformBarState();
}

class _AnimatedWaveformBarState extends State<AnimatedWaveformBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    // Initialize the animation with the starting height
    final initialHeight = max(
      widget.minHeight,
      widget.minHeight + (widget.level * (widget.maxHeight - widget.minHeight)),
    );

    _heightAnimation =
        Tween<double>(begin: initialHeight, end: initialHeight).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _updateAnimation();
    _animationController.forward();
  }

  @override
  void didUpdateWidget(AnimatedWaveformBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) {
      _updateAnimation();
      _animationController.forward(from: 0);
    }
  }

  void _updateAnimation() {
    final targetHeight = max(
      widget.minHeight,
      widget.minHeight + (widget.level * (widget.maxHeight - widget.minHeight)),
    );

    _heightAnimation = Tween<double>(
      begin:
          _heightAnimation.value, // Now safe to access since it's initialized
      end: targetHeight,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _heightAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: _heightAnimation.value,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      },
    );
  }
}
