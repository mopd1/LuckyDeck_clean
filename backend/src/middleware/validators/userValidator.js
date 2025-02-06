const { body, query, param, validationResult } = require('express-validator');

const validateUserFilters = [
    query('username').optional().isString().trim(),
    query('email').optional().isEmail().normalizeEmail(),
    query('is_active').optional().isBoolean(),
    query('is_admin').optional().isBoolean(),
    query('min_chips').optional().isInt({ min: 0 }),
    query('max_chips').optional().isInt({ min: 0 }),
    query('min_gems').optional().isInt({ min: 0 }),
    query('max_gems').optional().isInt({ min: 0 }),
    query('start_date').optional().isISO8601(),
    query('end_date').optional().isISO8601(),
    query('page').optional().isInt({ min: 1 }),
    query('sort_by').optional().isIn([
        'username', 'email', 'chips', 'gems', 'created_at', 
        'last_login', 'failed_login_attempts'
    ]),
    query('sort_order').optional().isIn(['asc', 'desc']),
    (req, res, next) => {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }
        next();
    }
];

const validateUserId = [
    param('id').isInt({ min: 1 }).withMessage('Invalid user ID'),
    (req, res, next) => {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }
        next();
    }
];

const validateUserUpdate = [
    body('username')
        .optional()
        .isString()
        .trim()
        .isLength({ min: 3, max: 50 })
        .withMessage('Username must be between 3 and 50 characters'),
    body('email')
        .optional()
        .isEmail()
        .normalizeEmail()
        .withMessage('Invalid email address'),
    body('is_active')
        .optional()
        .isBoolean()
        .withMessage('is_active must be a boolean'),
    body('chips')
        .optional()
        .isInt({ min: 0 })
        .withMessage('Chips must be a non-negative integer'),
    body('gems')
        .optional()
        .isInt({ min: 0 })
        .withMessage('Gems must be a non-negative integer'),
    body('admin_role')
        .optional()
        .isIn(['admin', 'superadmin', null])
        .withMessage('Invalid admin role'),
    (req, res, next) => {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({ errors: errors.array() });
        }
        next();
    }
];

module.exports = {
    validateUserFilters,
    validateUserId,
    validateUserUpdate
};