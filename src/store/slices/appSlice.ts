import { createSlice, type PayloadAction } from '@reduxjs/toolkit';

interface AppState {
  isInitialized: boolean;
}

const initialState: AppState = {
  isInitialized: false,
};

const appSlice = createSlice({
  name: 'app',
  initialState: initialState,
  reducers: {
    setInitialized: (state, action: PayloadAction<boolean>) => {
      state.isInitialized = action.payload;
    },
  },
});

export const { setInitialized } = appSlice.actions;
export default appSlice.reducer;
