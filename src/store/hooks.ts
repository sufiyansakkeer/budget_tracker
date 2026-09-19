import { useDispatch, useSelector } from 'react-redux';
import type { AppDispatch, RootState } from './store';

/**
 * Pre-typed Redux hooks.
 *
 * `withTypes` is a *function* that returns a typed copy of the hook, so it has
 * to be called: `withTypes<RootState>` on its own is a generic instantiation
 * expression that evaluates to the uncalled function itself.
 */
export const useAppDispatch = useDispatch.withTypes<AppDispatch>();
export const useAppSelector = useSelector.withTypes<RootState>();
