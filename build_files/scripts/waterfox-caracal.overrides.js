/* global user_pref */

/****************************************************************************
 * CARACAL OVERRIDES                                                       *
 * Caracal-only prefs appended after upstream Betterfox waterfox/user.js by *
 * scripts/fetch-waterfox-userjs.sh at image build time. Upstream prefs are *
 * maintained in yokoffing/Betterfox; only Caracal-specific changes belong  *
 * here. Appended last, so these win on conflict.                           *
 ***************************************************************************/

/** START: CARACAL OVERRIDES ***/
user_pref("browser.urlbar.doubleClickSelectsAll", true);
/** END: CARACAL OVERRIDES ***/