const { Op } = require('sequelize');
const { User } = require('../../models');

class UserController {
    static async listUsers(req, res) {
        try {
            const page = parseInt(req.query.page) || 1;
            const limit = 50;
            const offset = (page - 1) * limit;

            // Build filter conditions
            const where = {};
            
            if (req.query.username) {
                where.username = { [Op.like]: `%${req.query.username}%` };
            }
            
            if (req.query.email) {
                where.email = { [Op.like]: `%${req.query.email}%` };
            }
            
            if (req.query.is_active !== undefined) {
                where.is_active = req.query.is_active === 'true';
            }
            
            if (req.query.is_admin !== undefined) {
                where.is_admin = req.query.is_admin === 'true';
            }
            
            if (req.query.account_locked !== undefined) {
                where.account_locked = req.query.account_locked === 'true';
            }

            // Handle chips range
            if (req.query.min_chips !== undefined || req.query.max_chips !== undefined) {
                where.chips = {};
                if (req.query.min_chips !== undefined) {
                    where.chips[Op.gte] = parseInt(req.query.min_chips);
                }
                if (req.query.max_chips !== undefined) {
                    where.chips[Op.lte] = parseInt(req.query.max_chips);
                }
            }

            // Handle gems range
            if (req.query.min_gems !== undefined || req.query.max_gems !== undefined) {
                where.gems = {};
                if (req.query.min_gems !== undefined) {
                    where.gems[Op.gte] = parseInt(req.query.min_gems);
                }
                if (req.query.max_gems !== undefined) {
                    where.gems[Op.lte] = parseInt(req.query.max_gems);
                }
            }

            // Handle date ranges
            const dateFields = {
                created_at: ['start_date', 'end_date'],
                last_login: ['last_login_start', 'last_login_end'],
                last_free_chips_claim: ['last_claim_start', 'last_claim_end']
            };

            Object.entries(dateFields).forEach(([field, [startKey, endKey]]) => {
                if (req.query[startKey] || req.query[endKey]) {
                    where[field] = {};
                    if (req.query[startKey]) {
                        where[field][Op.gte] = new Date(req.query[startKey]);
                    }
                    if (req.query[endKey]) {
                        where[field][Op.lte] = new Date(req.query[endKey]);
                    }
                }
            });

            // Determine sort order
            const sortField = req.query.sort_by || 'created_at';
            const sortOrder = req.query.sort_order === 'asc' ? 'ASC' : 'DESC';

            const users = await User.findAndCountAll({
                where,
                order: [[sortField, sortOrder]],
                limit,
                offset,
                attributes: { exclude: ['password'] }
            });

            const totalPages = Math.ceil(users.count / limit);
            const hasNextPage = page < totalPages;
            const hasPreviousPage = page > 1;

            res.json({
                users: users.rows,
                pagination: {
                    current_page: page,
                    total_pages: totalPages,
                    total_items: users.count,
                    has_next_page: hasNextPage,
                    has_previous_page: hasPreviousPage,
                    items_per_page: limit
                }
            });
        } catch (error) {
            console.error('Error in listUsers:', error);
            res.status(500).json({ 
                error: 'Internal server error',
                message: error.message 
            });
        }
    }

    static async getUser(req, res) {
        try {
            const user = await User.findByPk(req.params.id, {
                attributes: { exclude: ['password'] }
            });

            if (!user) {
                return res.status(404).json({ error: 'User not found' });
            }

            res.json(user);
        } catch (error) {
            console.error('Error in getUser:', error);
            res.status(500).json({ 
                error: 'Internal server error',
                message: error.message 
            });
        }
    }

    static async updateUser(req, res) {
        try {
            const user = await User.findByPk(req.params.id);

            if (!user) {
                return res.status(404).json({ error: 'User not found' });
            }

            // Prevent updating admin status if not superadmin
            if (req.body.is_admin !== undefined && req.user.role !== 'superadmin') {
                return res.status(403).json({ 
                    error: 'Only superadmin can modify admin status' 
                });
            }

            // Update user
            await user.update(req.body);

            // Return updated user without password
            const updatedUser = user.toJSON();
            delete updatedUser.password;

            res.json(updatedUser);
        } catch (error) {
            console.error('Error in updateUser:', error);
            if (error.name === 'SequelizeUniqueConstraintError') {
                return res.status(400).json({ 
                    error: 'Username or email already exists' 
                });
            }
            res.status(500).json({ 
                error: 'Internal server error',
                message: error.message 
            });
        }
    }

    static async deleteUser(req, res) {
        try {
            const user = await User.findByPk(req.params.id);

            if (!user) {
                return res.status(404).json({ error: 'User not found' });
            }

            // Prevent deleting admin users if not superadmin
            if (user.is_admin && req.user.role !== 'superadmin') {
                return res.status(403).json({ 
                    error: 'Only superadmin can delete admin users' 
                });
            }

            await user.destroy();
            res.json({ message: 'User deleted successfully' });
        } catch (error) {
            console.error('Error in deleteUser:', error);
            res.status(500).json({ 
                error: 'Internal server error',
                message: error.message 
            });
        }
    }
}

module.exports = UserController;