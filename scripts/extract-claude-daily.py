#!/usr/bin/env python3
"""提取当天 Claude Code 会话记录，输出结构化 markdown。"""
import json, datetime, os, glob, sys, re

# 北京时间当天 00:00 ~ 24:00 = UTC 16:00 ~ 次日 16:00
tz_cst = datetime.timezone(datetime.timedelta(hours=8))
now = datetime.datetime.now(tz_cst)
today = sys.argv[1] if len(sys.argv) > 1 else now.strftime('%Y-%m-%d')
# 工作日切分：前一天 18:00 ~ 今天 18:00（不遗漏晚上加班记录）
date_end = datetime.datetime.strptime(today, '%Y-%m-%d').replace(hour=18, minute=0, second=0, tzinfo=tz_cst)
if now < date_end and sys.argv[1] is None:
    # 正常定时任务在 18:00 跑，end 就是今天 18:00
    pass
date_start = date_end - datetime.timedelta(days=1)
start_utc = date_start.astimezone(datetime.timezone.utc)
end_utc = date_end.astimezone(datetime.timezone.utc)

NOISE_PATTERNS = [
    re.compile(r'^Base directory for this skill'),
    re.compile(r'^\(Re-invocation of'),
    re.compile(r'^\[Image:'),
    re.compile(r'^\s*$'),
]

def is_noise(text):
    for pat in NOISE_PATTERNS:
        if pat.match(text):
            return True
    return False

def extract_text(content):
    """从 message.content 提取纯文本。"""
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        parts = []
        for item in content:
            if isinstance(item, dict) and item.get('type') == 'text':
                parts.append(item.get('text', '').strip())
        return '\n'.join(parts)
    return ''

def short_proj(name):
    return name.replace('-Users-qiuwenbo-', '~/').replace('-', '/')

base = os.path.expanduser('~/.claude/projects')
sessions = []

for f in sorted(glob.glob(base + '/**/*.jsonl', recursive=True)):
    if 'subagent' in f:
        continue
    proj_dir = os.path.basename(os.path.dirname(f))
    sid = os.path.basename(f).replace('.jsonl', '')
    user_msgs = []
    asst_summaries = []
    entrypoint = '?'
    cwd = '?'
    with open(f) as fh:
        for line in fh:
            try:
                d = json.loads(line.strip())
                ts_str = d.get('timestamp', '')
                if not ts_str:
                    continue
                ts = datetime.datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
                if ts < start_utc or ts >= end_utc:
                    continue
                if d.get('type') == 'user' and entrypoint == '?':
                    entrypoint = d.get('entrypoint', '?')
                    cwd = d.get('cwd', '?')
                if d.get('type') == 'user':
                    text = extract_text(d.get('message', {}).get('content', ''))
                    if text and not is_noise(text):
                        t = ts.astimezone(tz_cst).strftime('%H:%M')
                        user_msgs.append((t, text))
                elif d.get('type') == 'assistant':
                    text = extract_text(d.get('message', {}).get('content', ''))
                    if text and len(text) > 20:
                        t = ts.astimezone(tz_cst).strftime('%H:%M')
                        asst_summaries.append((t, text[:500]))
            except:
                pass
    if user_msgs or asst_summaries:
        proj_short = short_proj(proj_dir)
        sessions.append({
            'project': proj_short,
            'sid': sid[:8],
            'entrypoint': entrypoint,
            'cwd': cwd,
            'user_msgs': user_msgs,
            'asst_summaries': asst_summaries,
        })

# 输出 raw markdown
out_path = os.path.expanduser(f'~/.local/state/claude-daily/{today}-raw.md')
os.makedirs(os.path.dirname(out_path), exist_ok=True)

with open(out_path, 'w') as out:
    out.write(f'# Claude Code 会话记录 {today}\n\n')
    out.write(f'提取时间: {datetime.datetime.now(tz_cst).strftime("%Y-%m-%d %H:%M")}\n')
    out.write(f'会话数: {len(sessions)}\n\n')
    out.write('---\n\n')
    for s in sessions:
        out.write(f"## {s['project']} | session={s['sid']} | {s['entrypoint']}\n\n")
        if s['user_msgs']:
            out.write('### 用户提问\n')
            for t, m in s['user_msgs']:
                out.write(f'- [{t}] {m}\n')
            out.write('\n')
        if s['asst_summaries']:
            out.write('### 助手回复（摘要）\n')
            for t, m in s['asst_summaries']:
                out.write(f'- [{t}] {m[:200]}\n')
            out.write('\n')
        out.write('---\n\n')

print(out_path)
print(f"会话数: {len(sessions)}")
total_user = sum(len(s['user_msgs']) for s in sessions)
total_asst = sum(len(s['asst_summaries']) for s in sessions)
print(f"用户消息: {total_user}, 助手回复: {total_asst}")
