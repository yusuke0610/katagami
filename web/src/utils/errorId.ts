/**
 * ログ・サポート問い合わせと突合しやすい短いエラー ID を生成する。
 * backend の generate_error_id（12 桁 hex）と同じ形式に揃える。
 */
export function generateErrorId(): string {
  return crypto.randomUUID().replace(/-/g, "").slice(0, 12);
}
