import '../domain/models/expense_category.dart';

/// Canonical default categories — mirrors the seed in `database/schema.sql`.
/// Used for the first-run/offline experience and as the parser fixture in tests.
/// At runtime the app loads the user's own categories from Supabase instead.
const String kOtherCategoryId = 'other';

const List<ExpenseCategory> kDefaultCategories = [
  ExpenseCategory(
    id: 'food',
    name: 'Food & Groceries',
    icon: '🛒',
    color: '#2a78d6',
    sortOrder: 1,
    keywords: [
      'grocery', 'groceries', 'vegetable', 'vegetables', 'veggie', 'veggies',
      'milk', 'fruit', 'fruits', 'bread', 'egg', 'eggs', 'supermarket',
      'kirana', 'bigbasket', 'dmart', 'rice', 'atta'
    ],
  ),
  ExpenseCategory(
    id: 'dining',
    name: 'Dining Out',
    icon: '🍽️',
    color: '#eb6834',
    sortOrder: 2,
    keywords: [
      'restaurant', 'dining', 'dinner', 'lunch', 'breakfast', 'coffee', 'cafe',
      'tea', 'snack', 'snacks', 'swiggy', 'zomato', 'food', 'pizza', 'burger',
      'biryani', 'dosa'
    ],
  ),
  ExpenseCategory(
    id: 'transport',
    name: 'Transport',
    icon: '🚗',
    color: '#1baf7a',
    sortOrder: 3,
    keywords: [
      'uber', 'ola', 'taxi', 'cab', 'auto', 'rickshaw', 'petrol', 'diesel',
      'fuel', 'gas', 'bus', 'train', 'metro', 'flight', 'travel', 'parking',
      'toll', 'rapido', 'fastag'
    ],
  ),
  ExpenseCategory(
    id: 'shopping',
    name: 'Shopping',
    icon: '🛍️',
    color: '#eda100',
    sortOrder: 4,
    keywords: [
      'amazon', 'flipkart', 'clothes', 'clothing', 'shoes', 'shopping',
      'myntra', 'electronics', 'gadget', 'mobile', 'laptop', 'dress', 'shirt',
      'jeans'
    ],
  ),
  ExpenseCategory(
    id: 'bills',
    name: 'Bills & Utilities',
    icon: '🧾',
    color: '#e87ba4',
    sortOrder: 5,
    keywords: [
      'rent', 'bill', 'bills', 'electricity', 'water', 'internet', 'wifi',
      'broadband', 'recharge', 'dth', 'maintenance', 'emi', 'loan',
      'insurance', 'subscription', 'utility'
    ],
  ),
  ExpenseCategory(
    id: 'health',
    name: 'Health',
    icon: '💊',
    color: '#008300',
    sortOrder: 6,
    keywords: [
      'medicine', 'medicines', 'pharmacy', 'doctor', 'hospital', 'clinic',
      'health', 'gym', 'fitness', 'dental', 'dentist', 'checkup', 'lab',
      'apollo'
    ],
  ),
  ExpenseCategory(
    id: 'entertainment',
    name: 'Entertainment',
    icon: '🎬',
    color: '#4a3aa7',
    sortOrder: 7,
    keywords: [
      'movie', 'movies', 'netflix', 'spotify', 'prime', 'hotstar', 'game',
      'games', 'concert', 'entertainment', 'cinema', 'pvr', 'book', 'books',
      'party'
    ],
  ),
  ExpenseCategory(
    id: kOtherCategoryId,
    name: 'Other',
    icon: '•',
    color: '#e34948',
    sortOrder: 99,
    keywords: [],
  ),
];
