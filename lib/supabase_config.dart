/// Supabase 프로젝트 URL/anon key 설정
///
/// 사용법: supabase.com에서 만든 프로젝트의 Settings > API에서 URL과 anon key를 복사해 아래에 입력한다.
/// anon key는 RLS로 보호되는 공개 키라 커밋해도 안전하지만, 값을 로컬에만 두고 싶다면
/// `git update-index --skip-worktree lib/supabase_config.dart` 로 이 파일의 변경사항을 추적에서 제외할 수 있다.
class SupabaseConfig {
  static const url = 'https://opqmulhoxidtblpuerii.supabase.co';
  static const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wcW11bGhveGlkdGJscHVlcmlpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM5NDY0NTIsImV4cCI6MjA5OTUyMjQ1Mn0.dmWcl_U--HB5tr78lphWn1psJvxLMfN4LLD6mZt2mhA';

  static bool get isConfigured =>
      url.startsWith('https://') && !url.contains('YOUR_PROJECT') && anonKey != 'YOUR_ANON_KEY';
}
