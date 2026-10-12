/// A SQL prefix that adds `category_tree(root_id, id)`: one row for every
/// category together with each category it sits inside, itself included. For
/// `Food > Restaurant > Dinner` it holds (Food, Food), (Food, Restaurant),
/// (Food, Dinner), (Restaurant, Restaurant), (Restaurant, Dinner) and
/// (Dinner, Dinner).
///
/// So `id IN (SELECT id FROM category_tree WHERE root_id = ?)` means "this
/// category or anything inside it", at any depth, and joining on `id` and a
/// top-level `root_id` finds the top-level category a transaction belongs to.
///
/// `UNION` (not `UNION ALL`) makes the recursion stop even if a damaged
/// database had a category inside itself.
const categoryTreeCte =
    'WITH RECURSIVE category_tree(root_id, id) AS ('
    'SELECT id, id FROM categories '
    'UNION '
    'SELECT category_tree.root_id, c.id FROM categories c '
    'JOIN category_tree ON c.parent_id = category_tree.id) ';
