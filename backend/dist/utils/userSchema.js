"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildCurrentUserSelect = exports.buildAuthenticatedUserSelect = exports.buildAuthResponseUserSelect = exports.hasUserPersonalIdColumn = void 0;
const client_1 = require("@prisma/client");
const logger_1 = require("./logger");
const prisma_1 = require("./prisma");
let cachedHasUserPersonalIdColumn = null;
const hasUserPersonalIdColumn = async () => {
    if (cachedHasUserPersonalIdColumn !== null) {
        return cachedHasUserPersonalIdColumn;
    }
    try {
        const result = await prisma_1.prisma.$queryRaw(client_1.Prisma.sql `
      SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'User'
          AND column_name = 'personalId'
      ) AS "exists"
    `);
        cachedHasUserPersonalIdColumn = Boolean(result[0]?.exists);
        if (!cachedHasUserPersonalIdColumn) {
            logger_1.logger.warn('User.personalId column is missing; continuing without personalId until migrations are repaired.');
        }
    }
    catch (err) {
        logger_1.logger.warn(`Could not verify User.personalId column availability: ${String(err)}`);
        cachedHasUserPersonalIdColumn = false;
    }
    return cachedHasUserPersonalIdColumn;
};
exports.hasUserPersonalIdColumn = hasUserPersonalIdColumn;
const buildAuthResponseUserSelect = (includePersonalId) => ({
    id: true,
    email: true,
    name: true,
    role: true,
    country: true,
    companyName: true,
    agentLicense: true,
    agentType: true,
    website: true,
    createdAt: true,
    ...(includePersonalId ? { personalId: true } : {}),
});
exports.buildAuthResponseUserSelect = buildAuthResponseUserSelect;
const buildAuthenticatedUserSelect = (includePersonalId) => ({
    id: true,
    email: true,
    name: true,
    password: true,
    role: true,
    country: true,
    isVerified: true,
    isBanned: true,
    refreshToken: true,
    createdAt: true,
    ...(includePersonalId ? { personalId: true } : {}),
});
exports.buildAuthenticatedUserSelect = buildAuthenticatedUserSelect;
const buildCurrentUserSelect = (includePersonalId) => ({
    id: true,
    email: true,
    name: true,
    phone: true,
    avatar: true,
    role: true,
    country: true,
    isVerified: true,
    isKycVerified: true,
    kycStatus: true,
    cvThemeColor: true,
    companyName: true,
    registrationNumber: true,
    agentLicense: true,
    agentType: true,
    website: true,
    businessDescription: true,
    socialLinks: true,
    createdAt: true,
    ...(includePersonalId ? { personalId: true } : {}),
});
exports.buildCurrentUserSelect = buildCurrentUserSelect;
//# sourceMappingURL=userSchema.js.map