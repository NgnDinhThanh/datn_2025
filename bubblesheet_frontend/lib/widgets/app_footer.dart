import 'package:flutter/material.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.grey[300],
      child: Column(
        children: [
          const SizedBox(height: 40),
          Divider(color: Colors.grey[300], height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                Text(
                  'BubbleSheet © 2025',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    _buildLink('About'),
                    Text(' • ', style: TextStyle(color: Colors.grey[400])),
                    _buildLink('Help Center'),
                    Text(' • ', style: TextStyle(color: Colors.grey[400])),
                    _buildLink('Privacy'),
                    Text(' • ', style: TextStyle(color: Colors.grey[400])),
                    _buildLink('Terms'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLink(String text) {
    return InkWell(
      onTap: () {
      },
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 13,
        ),
      ),
    );
  }
}