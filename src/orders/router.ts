import { Request, Router } from 'express';
import { asyncHandler } from '../asyncHandler';
import { badRequest, notFound } from '../errors';
import { currentUser, requireAuth, requireStaff } from '../middleware/auth';
import { parseId } from '../validation';
import * as service from './service';

export const ordersRouter = Router();

function orderId(req: Request): number {
  const id = parseId(req.params.id);
  if (id === null) throw notFound('order not found');
  return id;
}

/**
 * Optional discount code in the checkout body: `couponCode` (the storefront's name for it) or `discountCode`.
 * A missing or non-object body, or a missing/null field, means no code.
 */
function discountCodeField(req: Request): string | undefined {
  const body = req.body as unknown;
  if (body === null || typeof body !== 'object' || Array.isArray(body)) return undefined;
  const fields = body as Record<string, unknown>;
  const value = fields.couponCode ?? fields.discountCode;
  if (value === undefined || value === null) return undefined;
  if (typeof value !== 'string' || value.trim() === '') throw badRequest('couponCode must be a non-empty string');
  return value.trim();
}

ordersRouter.post(
  '/checkout',
  requireAuth,
  asyncHandler(async (req, res) => {
    const order = await service.checkout(currentUser(req).id, { discountCode: discountCodeField(req) });
    res.status(201).json({ order });
  }),
);

ordersRouter.get(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    res.json({ orders: await service.listForUser(currentUser(req).id) });
  }),
);

ordersRouter.get(
  '/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    res.json({ order: await service.getForUser(currentUser(req).id, orderId(req)) });
  }),
);

ordersRouter.post(
  '/:id/cancel',
  requireAuth,
  asyncHandler(async (req, res) => {
    res.json({ order: await service.cancel(currentUser(req).id, orderId(req)) });
  }),
);

ordersRouter.post(
  '/:id/ship',
  requireStaff,
  asyncHandler(async (req, res) => {
    res.json({ order: await service.ship(orderId(req)) });
  }),
);
