import 'package:flutter/material.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final score = _score(password);
    final color = score <= 1
        ? Colors.red
        : score <= 3
            ? Colors.amber.shade800
            : Colors.green;
    final label = score <= 1
        ? 'Weak'
        : score <= 3
            ? 'Medium'
            : 'Good';

    return Semantics(
      label: 'Password strength: $label',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Password strength',
                  style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: score / 5,
            minHeight: 5,
            borderRadius: BorderRadius.circular(3),
            color: color,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 4),
          Text(
              'Use at least 8 characters. Letters, numbers, and symbols make it stronger.',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  int _score(String value) {
    var score = value.length >= 8 ? 1 : 0;
    if (RegExp(r'[a-z]').hasMatch(value) && RegExp(r'[A-Z]').hasMatch(value)) {
      score++;
    }
    if (RegExp(r'[0-9]').hasMatch(value)) {
      score++;
    }
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      score++;
    }
    if (value.length >= 12) {
      score++;
    }
    return score;
  }
}
