const form = document.querySelector('#note-form');
const input = document.querySelector('#content');
const button = document.querySelector('#save');
const status = document.querySelector('#status');
const notes = document.querySelector('#notes');
const counter = document.querySelector('#count');
let savedNotes = [];

function render() {
  notes.replaceChildren();
  document.querySelector('#total').textContent = `${savedNotes.length}개`;
  if (!savedNotes.length) {
    const empty = document.createElement('p');
    empty.className = 'empty';
    empty.textContent = '아직 메모가 없어요. 첫 번째 생각을 남겨보세요.';
    notes.append(empty);
  }
  for (const note of savedNotes) {
    const card = document.createElement('article');
    const text = document.createElement('p');
    const date = document.createElement('time');
    text.textContent = note.content;
    date.dateTime = note.createdAt;
    date.textContent = new Date(note.createdAt).toLocaleString('ko-KR');
    card.append(text, date);
    notes.append(card);
  }
}
async function request(url, options) {
  const response = await fetch(url, options);
  const body = await response.json();
  if (!response.ok) throw new Error(body.error || '요청을 처리하지 못했습니다.');
  return body;
}
input.addEventListener('input', () => { counter.textContent = `${input.value.length.toLocaleString()} / 10,000`; });
form.addEventListener('submit', async (event) => {
  event.preventDefault();
  if (!input.value.trim()) { status.textContent = '메모 내용을 입력해주세요.'; input.focus(); return; }
  button.disabled = true;
  input.disabled = true;
  status.textContent = '저장 중…';
  try {
    const note = await request('/api/notes', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ content: input.value }) });
    savedNotes.unshift(note);
    render();
    input.value = '';
    counter.textContent = '0 / 10,000';
    status.textContent = '메모를 저장했어요.';
  } catch (error) { status.textContent = `저장 실패: ${error.message}`; }
  finally { button.disabled = false; input.disabled = false; input.focus(); }
});
button.disabled = true;
request('/api/notes').then((data) => { savedNotes = data; render(); })
  .catch(() => { notes.textContent = '메모를 불러오지 못했습니다. 페이지를 새로고침해주세요.'; })
  .finally(() => { button.disabled = false; });
