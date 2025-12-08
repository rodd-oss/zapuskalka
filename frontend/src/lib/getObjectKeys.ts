// By default, Object.keys returns string[] which is not type-safe.
// This utility function provides a type-safe way to get the keys of an object.
export const getObjectKeys = <T extends object>(obj: T): Array<keyof T> =>
  Object.keys(obj) as Array<keyof T>
