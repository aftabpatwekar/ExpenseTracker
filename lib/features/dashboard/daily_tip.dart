import 'package:flutter/material.dart';

import '../../core/glass.dart';
import '../../core/theme.dart';

/// A rotating "money tip of the day" card. One tip per calendar day, chosen
/// deterministically so it stays the same all day and changes at midnight.
class DailyTipCard extends StatelessWidget {
  const DailyTipCard({super.key});

  static const List<String> _tips = [
    'Pay yourself first — move a fixed amount to savings the day you get paid, before you spend.',
    'Follow the 50/30/20 rule: 50% needs, 30% wants, 20% savings & debt.',
    'Wait 24 hours before any non-essential purchase over ₹2,000. Most urges fade.',
    'Automate a monthly SIP into an index fund — consistency beats timing the market.',
    'Build an emergency fund covering 3–6 months of expenses before investing aggressively.',
    'Review subscriptions monthly. Cancel the ones you haven\'t used in 30 days.',
    'Cook one more meal at home each week — small food savings compound fast.',
    'Clear high-interest debt (credit cards) before chasing investment returns.',
    'Track every expense for a week — awareness alone cuts spending by ~10%.',
    'Set a specific goal (trip, gadget, fund). Money saved toward a goal sticks.',
    'Use a separate account for savings so it\'s out of sight, out of temptation.',
    'Buy quality for things you use daily — cost per use matters more than price.',
    'Increase your SIP by 10% every year to keep pace with your rising income.',
    'Compare the yearly cost, not the monthly one, when judging a subscription.',
    'Keep 1 month of buffer in your spending account to avoid overdraft fees.',
    'Invest in what you understand. If you can\'t explain it, don\'t put money in it.',
    'A 1% higher return over 30 years can mean lakhs more — fees matter.',
    'Round up purchases and stash the change — micro-saving adds up quietly.',
    'Negotiate recurring bills (internet, insurance) once a year. It works more often than you\'d think.',
    'Don\'t confuse income with wealth — wealth is what you keep and grow.',
    'Set your credit card to auto-pay the full balance to dodge interest.',
    'Diversify: never keep all your money in one stock, sector, or asset.',
    'The best time to start investing was yesterday. The second best is today.',
    'Track your net worth monthly — one number tells you if you\'re moving forward.',
    'Avoid lifestyle creep — bank raises instead of upgrading your spending.',
    'Keep an eye on the small daily leaks (coffee, delivery fees); they out-total big buys.',
    'Use annual plans for services you\'ll keep — they\'re usually 15–20% cheaper.',
    'Before a big buy, ask: how many hours of work does this cost me?',
    'Reinvest dividends and interest — compounding is the quiet millionaire-maker.',
    'Check your bank and card statements for wrong or forgotten charges each month.',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final dayIndex = now.difference(DateTime(now.year)).inDays;
    final tip = _tips[dayIndex % _tips.length];

    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFF6C445), Color(0xFFF59E0B)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: kGold.withAlpha(70),
                    blurRadius: 14,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: const Center(
                child: Text('💡', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MONEY TIP OF THE DAY',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: kGold,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6)),
                const SizedBox(height: 4),
                Text(tip,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(height: 1.35, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
