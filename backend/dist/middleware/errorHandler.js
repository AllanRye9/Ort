"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createError = exports.errorHandler = void 0;
const logger_1 = require("../utils/logger");
const isPrismaKnownRequestError = (err) => {
    return err instanceof Error && typeof err.code === 'string';
};
const isPrismaErrorByName = (err, name) => {
    return err instanceof Error && err.name === name;
};
const errorHandler = (err, _req, res, _next) => {
    // Handle Prisma known request errors (e.g. unique constraint, foreign key, not found)
    if (isPrismaKnownRequestError(err)) {
        switch (err.code) {
            case 'P2000':
                res.status(400).json({ message: 'One or more fields are too long.' });
                return;
            case 'P2001':
                res.status(404).json({ message: 'The requested record was not found.' });
                return;
            case 'P2002':
                res.status(409).json({ message: 'A record with this information already exists.' });
                return;
            case 'P2011':
                res.status(400).json({ message: 'A required field is missing.' });
                return;
            case 'P2025':
                res.status(404).json({ message: 'The requested record was not found.' });
                return;
            case 'P2003':
                res.status(400).json({ message: 'Related record not found. Please check the provided IDs.' });
                return;
            case 'P2014':
                res.status(400).json({ message: 'Invalid relation — the referenced record does not exist.' });
                return;
            case 'P2021':
                logger_1.logger.error(`Prisma error ${err.code} — table missing (run migrations):`, err);
                res.status(503).json({ message: 'Service unavailable. Database schema is not ready.' });
                return;
            case 'P2022':
                logger_1.logger.error(`Prisma error ${err.code} — column missing (run migrations):`, err);
                res.status(503).json({ message: 'Service unavailable. Database schema is out of date.' });
                return;
            case 'P2024':
                logger_1.logger.error(`Prisma error ${err.code} — connection pool timeout:`, err);
                res.status(503).json({ message: 'Database is busy. Please try again in a moment.' });
                return;
            default:
                logger_1.logger.error(`Prisma error ${err.code}:`, err);
                res.status(500).json({ message: 'A database error occurred. Please try again.' });
                return;
        }
    }
    // Handle Prisma validation errors (malformed queries)
    if (isPrismaErrorByName(err, 'PrismaClientValidationError')) {
        logger_1.logger.error('Prisma validation error:', err);
        res.status(400).json({ message: 'Invalid request data.' });
        return;
    }
    // Handle Prisma initialization / connection errors
    if (isPrismaErrorByName(err, 'PrismaClientInitializationError')) {
        logger_1.logger.error('Prisma initialization error (cannot connect to database):', err);
        res.status(503).json({ message: 'Unable to connect to the database. Please try again shortly.' });
        return;
    }
    // Handle Prisma rust-engine panic errors
    if (isPrismaErrorByName(err, 'PrismaClientRustPanicError')) {
        logger_1.logger.error('Prisma engine panic error:', err);
        res.status(500).json({ message: 'An unexpected database engine error occurred. Please try again.' });
        return;
    }
    const appErr = err;
    const statusCode = appErr.statusCode || 500;
    const message = appErr.isOperational ? appErr.message : 'Internal server error';
    if (!appErr.isOperational) {
        logger_1.logger.error('Unexpected error:', err);
    }
    res.status(statusCode).json({
        message,
        ...(process.env.NODE_ENV === 'development' && { stack: appErr.stack }),
    });
};
exports.errorHandler = errorHandler;
const createError = (message, statusCode) => {
    const error = new Error(message);
    error.statusCode = statusCode;
    error.isOperational = true;
    return error;
};
exports.createError = createError;
//# sourceMappingURL=errorHandler.js.map