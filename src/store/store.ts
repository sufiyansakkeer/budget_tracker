//* Store is a kind of a global statemanagement setup.
import { configureStore } from '@reduxjs/toolkit';
import { persistSettingsMiddleware } from './middleware/persistSettings';
import appReducer from './slices/appSlice';
import settingsReducer from './slices/settingsSlice';

//* createing the redux store
export const store = configureStore({
  //* reducer is a function determine how the application state changes in response to action
  reducer: {
    app: appReducer,
    settings: settingsReducer,
  },
  //* the persist listener runs *before* the default middleware so a settings
  //* change is mirrored into MMKV as soon as it is dispatched
  middleware: getDefaultMiddleware =>
    getDefaultMiddleware().prepend(persistSettingsMiddleware.middleware),
});

//* [store.getState] comming from redux which will return the current Redux state.
//* [typeof] will give the datatype of the function i.e. it will return the function
//* [ReturnType] is a inbuild typescript function to get the return type .
//* i.e. it will take the datatype of the return type of the function

//* that return type will be asigned to the RootState

export type RootState = ReturnType<typeof store.getState>;

//* [store.dispatch] is function you use to send an action at redux
export type AppDispatch = typeof store.dispatch;
