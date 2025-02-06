const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const rateLimit = require('express-rate-limit');
const { promisify } = require('util');

// Rate limiting configuration
const loginLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 5, // limit each IP to 5 login attempts per window
    message: 'Too many login attempts, please try again later'
});

const generalLimiter = rateLimit({
    windowMs: 60 * 1000, // 1 minute
    max: 100 // limit each IP to 100 requests per minute
});

// Password hashing configuration
const SALT_ROUNDS = 10;

class AuthMiddleware {
    static async hashPassword(password) {
        return await bcrypt.hash(password, SALT_ROUNDS);
    }

    static async comparePassword(password, hash) {
        return await bcrypt.compare(password, hash);
    }

    static generateToken(user) {
        return jwt.sign(
            { 
                id: user.id, 
                email: user.email,
                role: user.admin_role || 'user'
            },
            process.env.JWT_SECRET,
            { expiresIn: '24h' }
        );
    }

    static generateRefreshToken(user) {
        return jwt.sign(
            { id: user.id },
            process.env.JWT_REFRESH_SECRET,
            { expiresIn: '7d' }
        );
    }

    static async verifyToken(req, res, next) {
        try {
            const authHeader = req.headers.authorization;
            if (!authHeader) {
                return res.status(401).json({ error: 'No token provided' });
            }

            const token = authHeader.split(' ')[1];
            const decoded = await promisify(jwt.verify)(token, process.env.JWT_SECRET);
            
            // Add user data to request
            req.user = decoded;
            next();
        } catch (error) {
            if (error.name === 'TokenExpiredError') {
                return res.status(401).json({ error: 'Token expired' });
            }
            return res.status(401).json({ error: 'Invalid token' });
        }
    }

    static async refreshToken(req, res) {
        try {
            const { refreshToken } = req.body;
            if (!refreshToken) {
                return res.status(401).json({ error: 'No refresh token provided' });
            }

            const decoded = await promisify(jwt.verify)(refreshToken, process.env.JWT_REFRESH_SECRET);
            const newToken = jwt.sign(
                { id: decoded.id },
                process.env.JWT_SECRET,
                { expiresIn: '24h' }
            );

            res.json({ token: newToken });
        } catch (error) {
            return res.status(401).json({ error: 'Invalid refresh token' });
        }
    }

    // Middleware to check user role
    static checkRole(roles) {
        return (req, res, next) => {
            if (!roles.includes(req.user.role)) {
                return res.status(403).json({ error: 'Insufficient permissions' });
            }
            next();
        };
    }

    // Account lockout check
    static async checkAccountLock(user) {
        if (user.account_locked) {
            const lockUntil = new Date(user.account_locked_until);
            if (lockUntil > new Date()) {
                const remainingTime = Math.ceil((lockUntil - new Date()) / 1000 / 60);
                throw new Error(`Account locked. Try again in ${remainingTime} minutes`);
            }
        }
    }

    // Password validation rules
    static validatePassword(password) {
        const minLength = 8;
        const hasUpperCase = /[A-Z]/.test(password);
        const hasLowerCase = /[a-z]/.test(password);
        const hasNumbers = /\d/.test(password);
        const hasSpecialChar = /[!@#$%^&*(),.?":{}|<>]/.test(password);

        if (password.length < minLength) {
            throw new Error('Password must be at least 8 characters long');
        }
        if (!hasUpperCase || !hasLowerCase) {
            throw new Error('Password must contain both uppercase and lowercase letters');
        }
        if (!hasNumbers) {
            throw new Error('Password must contain at least one number');
        }
        if (!hasSpecialChar) {
            throw new Error('Password must contain at least one special character');
        }
    }
}

module.exports = {
    AuthMiddleware,
    loginLimiter,
    generalLimiter
};