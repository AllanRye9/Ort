-- AlterEnum: add USD to Currency
ALTER TYPE "Currency" ADD VALUE IF NOT EXISTS 'USD';
