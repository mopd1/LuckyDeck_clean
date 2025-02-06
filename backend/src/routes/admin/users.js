const express = require('express');
const router = express.Router();
const { AuthMiddleware } = require('../../middleware/auth');
const { validateUserFilters, validateUserId, validateUserUpdate } = require('../../middleware/validators/userValidator');
const UserController = require('../../controllers/admin/userController');

router.use(AuthMiddleware.verifyToken);
router.use(AuthMiddleware.checkRole(['admin', 'superadmin']));

// GET /api/admin/users - List users
router.get('/', validateUserFilters, UserController.listUsers);

// GET /api/admin/users/:id - Get single user
router.get('/:id', validateUserId, UserController.getUser);

// PUT /api/admin/users/:id - Update user
router.put('/:id', [validateUserId, validateUserUpdate], UserController.updateUser);

// DELETE /api/admin/users/:id - Delete user
router.delete('/:id', validateUserId, UserController.deleteUser);

module.exports = router;