/**
 * countrySwitch.ts
 *
 * Shared flag that both CountryContext and the API interceptor read/write.
 * Using a standalone module avoids the circular import that would occur if
 * CountryContext imported from AuthContext or api.ts imported from CountryContext.
 */

let _active = false;

/** Set to true while a country switch animation is in progress. */
export function setCountrySwitching(active: boolean): void {
  _active = active;
}

/** Returns true while a country switch is in progress. */
export function isCountrySwitching(): boolean {
  return _active;
}
