import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/core/default_categories.dart';
import 'package:expense_tracker/domain/services/expense_parser.dart';

void main() {
  final parser =
      ExpenseParser(kDefaultCategories, fallbackCategoryId: kOtherCategoryId);

  void check(String input, double amount, String categoryId, String note) {
    final r = parser.parse(input);
    expect(r.amount, amount, reason: 'amount for "$input"');
    expect(r.categoryId, categoryId, reason: 'category for "$input"');
    expect(r.note, note, reason: 'note for "$input"');
  }

  group('amount + category + note', () {
    test('natural sentence', () =>
        check('spent 250 on groceries for weekly veggies', 250, 'food',
            'groceries weekly veggies'));
    test('terse order', () =>
        check('250 groceries weekly veggies', 250, 'food',
            'groceries weekly veggies'));
    test('rs prefix + shopping', () =>
        check('paid rs 1200 for shoes on myntra', 1200, 'shopping',
            'shoes myntra'));
    test('transport', () =>
        check('uber 340 to airport', 340, 'transport', 'uber to airport'));
    test('dining keeps "at"', () =>
        check('lunch at swiggy 180', 180, 'dining', 'lunch at swiggy'));
    test('bills', () =>
        check('electricity bill 2300', 2300, 'bills', 'electricity bill'));
    test('health', () =>
        check('bought medicines 320 from apollo pharmacy', 320, 'health',
            'medicines from apollo pharmacy'));
    test('entertainment', () =>
        check('movie tickets 500 pvr', 500, 'entertainment',
            'movie tickets pvr'));
    test('single word', () => check('coffee 90', 90, 'dining', 'coffee'));
    test('rent', () => check('gave 5000 rent', 5000, 'bills', 'gave rent'));
    test('petrol', () => check('petrol 2000', 2000, 'transport', 'petrol'));
    test('no keyword -> Other', () =>
        check('random thing 75', 75, 'other', 'random thing'));
  });

  group('number formats', () {
    test('western thousands', () =>
        check('1,250 amazon headphones', 1250, 'shopping', 'amazon headphones'));
    test('indian lakh grouping', () =>
        check('2,00,000 flat token amount rent', 200000, 'bills',
            'flat token amount rent'));
    test('millions', () =>
        check('1,000,000 big shopping', 1000000, 'shopping', 'big shopping'));
    test('decimal', () => check('3.50 coffee', 3.5, 'dining', 'coffee'));
    test('rs prefix', () => check('rs 45 tea', 45, 'dining', 'tea'));
  });

  group('edge cases', () {
    test('no number -> amount 0, note preserved', () =>
        check('no number here just groceries', 0, 'food',
            'no number here just groceries'));
    test('empty input', () {
      final r = parser.parse('   ');
      expect(r.amount, 0);
      expect(r.categoryId, 'other');
    });
  });
}
