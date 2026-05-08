export type LogScalar = boolean | number | string | null | undefined;
type LogArray = LogScalar[];
export type LogValue = LogScalar | LogArray;
export type LogBindings = Record<string, LogValue | undefined>;
