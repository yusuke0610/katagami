import type { ErrorCodeKey } from "./errorCodes";

type RecoveryAction = {
  label: string;
  fn: (() => void) | null;
};

/**
 * エラーコード → メッセージ + 回復アクションのマップ。
 *
 * キーは `web/src/constants/errorCodes.ts` の `ErrorCodeKey` で型縛り。
 * backend `backend/app/core/errors.py:ErrorCode` に新しいコードを追加した場合、
 * ERROR_CODES と本マップの両方に同時追加が必要（型エラーで漏れを検出）。
 */
export const ERROR_CONFIG: Record<
  ErrorCodeKey,
  {
    message: string;
    recovery: RecoveryAction | null;
  }
> = {
  VALIDATION_ERROR: {
    message: "入力内容が正しくありません",
    recovery: { label: "入力内容を見直す", fn: null },
  },
  INTERNAL_ERROR: {
    message: "予期しないエラーが発生しました",
    recovery: { label: "再読み込みする", fn: () => window.location.reload() },
  },
};
