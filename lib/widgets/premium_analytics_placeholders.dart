import 'package:flutter/material.dart';

import 'dart:collection';

// NOTE: Keep this file independent from owner_dashboard_screen.dart.
// We don't need the concrete Review type for placeholder UI.

/// Simple placeholders to keep Premium Analytics UI compiling.

class _ReviewLike {
  final dynamic _;
  const _ReviewLike(this._);
}

/// Simple placeholders to keep Premium Analytics UI compiling.

///
/// These can later be replaced with real AI insights/trend logic.
class AIReviewInsightsCard extends StatelessWidget {
  final List<Object?> reviews;


  const AIReviewInsightsCard({super.key, required this.reviews});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined, size: 18, color: Color(0xFF1D4ED8)),
              SizedBox(width: 8),
              Text('AI Review Insights', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'Preview-only: insight highlights will be generated here for AI-upgraded accounts.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.35),
          ),
        ],
      ),
    );
  }
}

class ReviewTrendsCard extends StatelessWidget {
  final List<Object?> reviews;

  const ReviewTrendsCard({super.key, required this.reviews});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Icons.trending_up_outlined, size: 18, color: Color(0xFFB45309)),
              SizedBox(width: 8),
              Text('Review Trends', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'Preview-only: sentiment momentum trends will be shown here for AI-upgraded accounts.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.35),
          ),
        ],
      ),
    );
  }
}

