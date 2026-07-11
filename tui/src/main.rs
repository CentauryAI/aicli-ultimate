// aicli-tui: whiptail replacement (checklist + menu) for the aicli installer.
// Renders on stderr so stdout stays clean for $(...) capture.

use std::io::{self, Write};

use ratatui::{
    crossterm::{
        event::{
            self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, KeyEventKind,
            KeyModifiers, MouseButton, MouseEventKind,
        },
        execute,
        terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
    },
    layout::{Constraint, Layout, Position, Rect},
    style::Style,
    widgets::{Block, List, ListItem, ListState, Paragraph, Scrollbar, ScrollbarOrientation, ScrollbarState},
    Frame, Terminal,
};

const CHECK_HINT: &str =
    "↑↓ move · space toggle · a all · n none · enter ok · q cancel · mouse: click/scroll";
const MENU_HINT: &str = "↑↓ move · enter ok · q cancel · mouse: click/scroll";
const USAGE: &str = "usage: aicli-tui checklist TITLE TAG DESC ON|OFF [TAG DESC ON|OFF ...]\n       aicli-tui menu TITLE TAG DESC [TAG DESC ...]";

#[derive(Debug, PartialEq)]
struct Item {
    tag: String,
    desc: String,
    on: bool,
}

#[derive(Debug, PartialEq)]
enum Cmd {
    Checklist { title: String, items: Vec<Item> },
    Menu { title: String, items: Vec<Item> },
}

fn parse_args(args: &[String]) -> Result<Cmd, String> {
    let mode = args.first().ok_or(USAGE)?;
    match mode.as_str() {
        "checklist" => {
            let title = args.get(1).ok_or("checklist: missing TITLE")?.clone();
            let rest = &args[2..];
            if rest.is_empty() || rest.len() % 3 != 0 {
                return Err("checklist: expected TAG DESC ON|OFF triples".into());
            }
            let mut items = Vec::new();
            for c in rest.chunks(3) {
                let on = match c[2].to_ascii_uppercase().as_str() {
                    "ON" => true,
                    "OFF" => false,
                    bad => return Err(format!("checklist: bad state {bad:?}, expected ON|OFF")),
                };
                items.push(Item { tag: c[0].clone(), desc: c[1].clone(), on });
            }
            Ok(Cmd::Checklist { title, items })
        }
        "menu" => {
            let title = args.get(1).ok_or("menu: missing TITLE")?.clone();
            let rest = &args[2..];
            if rest.is_empty() || rest.len() % 2 != 0 {
                return Err("menu: expected TAG DESC pairs".into());
            }
            let items = rest
                .chunks(2)
                .map(|c| Item { tag: c[0].clone(), desc: c[1].clone(), on: false })
                .collect();
            Ok(Cmd::Menu { title, items })
        }
        bad => Err(format!("unknown mode {bad:?}\n{USAGE}")),
    }
}

struct App {
    title: String,
    items: Vec<Item>,
    checklist: bool,
    cursor: usize,
    tag_width: usize,
    list_state: ListState,
    // rects captured on each draw, for exact mouse hit-testing
    list_rect: Rect,
    ok_rect: Rect,
    cancel_rect: Rect,
}

impl App {
    fn new(cmd: Cmd) -> Self {
        let (title, items, checklist) = match cmd {
            Cmd::Checklist { title, items } => (title, items, true),
            Cmd::Menu { title, items } => (title, items, false),
        };
        let tag_width = items.iter().map(|i| i.tag.chars().count()).max().unwrap_or(0);
        App {
            title,
            items,
            checklist,
            cursor: 0,
            tag_width,
            list_state: ListState::default(),
            list_rect: Rect::default(),
            ok_rect: Rect::default(),
            cancel_rect: Rect::default(),
        }
    }

    fn move_cursor(&mut self, delta: isize) {
        let last = self.items.len() - 1; // items never empty (parser guarantees)
        self.cursor = self.cursor.saturating_add_signed(delta).min(last);
    }

    fn output(&self) -> Vec<String> {
        if self.checklist {
            self.items.iter().filter(|i| i.on).map(|i| i.tag.clone()).collect()
        } else {
            vec![self.items[self.cursor].tag.clone()]
        }
    }
}

fn ui(f: &mut Frame, app: &mut App) {
    let block = Block::bordered().title(app.title.as_str());
    let inner = block.inner(f.area());
    f.render_widget(block, f.area());

    let [list_area, btn_area, hint_area] = Layout::vertical([
        Constraint::Min(1),
        Constraint::Length(1),
        Constraint::Length(1),
    ])
    .areas(inner);
    app.list_rect = list_area;

    let rows: Vec<ListItem> = app
        .items
        .iter()
        .map(|i| {
            let text = if app.checklist {
                let mark = if i.on { 'x' } else { ' ' };
                format!("[{mark}] {:<w$}  {}", i.tag, i.desc, w = app.tag_width)
            } else {
                format!("{:<w$}  {}", i.tag, i.desc, w = app.tag_width)
            };
            ListItem::new(text)
        })
        .collect();
    let list = List::new(rows).highlight_style(Style::new().reversed().bold());
    app.list_state.select(Some(app.cursor));
    f.render_stateful_widget(list, list_area, &mut app.list_state);

    if app.items.len() > list_area.height as usize {
        let mut sb = ScrollbarState::new(app.items.len()).position(app.cursor);
        f.render_stateful_widget(
            Scrollbar::new(ScrollbarOrientation::VerticalRight),
            list_area,
            &mut sb,
        );
    }

    // buttons, centered; rects stored for hit-testing
    let (ok, cancel, gap) = ("[ OK ]", "[ Cancel ]", 3u16);
    let total = ok.len() as u16 + gap + cancel.len() as u16;
    let x0 = btn_area.x + btn_area.width.saturating_sub(total) / 2;
    app.ok_rect = Rect::new(x0, btn_area.y, ok.len() as u16, 1).intersection(btn_area);
    app.cancel_rect =
        Rect::new(x0 + ok.len() as u16 + gap, btn_area.y, cancel.len() as u16, 1)
            .intersection(btn_area);
    f.render_widget(Paragraph::new(ok).style(Style::new().white().on_green().bold()), app.ok_rect);
    f.render_widget(
        Paragraph::new(cancel).style(Style::new().white().on_red().bold()),
        app.cancel_rect,
    );

    let hint = if app.checklist { CHECK_HINT } else { MENU_HINT };
    f.render_widget(Paragraph::new(hint).style(Style::new().dim()).centered(), hint_area);
}

/// Event loop. Returns Some(output lines) on confirm, None on cancel.
fn run_app(
    terminal: &mut Terminal<ratatui::backend::CrosstermBackend<io::Stderr>>,
    app: &mut App,
) -> io::Result<Option<Vec<String>>> {
    loop {
        terminal.draw(|f| ui(f, app))?;
        match event::read()? {
            Event::Key(k) if k.kind == KeyEventKind::Press => {
                if k.modifiers.contains(KeyModifiers::CONTROL) && k.code == KeyCode::Char('c') {
                    return Ok(None);
                }
                let page = app.list_rect.height.max(1) as isize;
                match k.code {
                    KeyCode::Up | KeyCode::Char('k') => app.move_cursor(-1),
                    KeyCode::Down | KeyCode::Char('j') => app.move_cursor(1),
                    KeyCode::PageUp => app.move_cursor(-page),
                    KeyCode::PageDown => app.move_cursor(page),
                    KeyCode::Home => app.cursor = 0,
                    KeyCode::End => app.cursor = app.items.len() - 1,
                    KeyCode::Char(' ') if app.checklist => {
                        app.items[app.cursor].on = !app.items[app.cursor].on;
                    }
                    KeyCode::Char('a') if app.checklist => {
                        app.items.iter_mut().for_each(|i| i.on = true);
                    }
                    KeyCode::Char('n') if app.checklist => {
                        app.items.iter_mut().for_each(|i| i.on = false);
                    }
                    KeyCode::Enter => return Ok(Some(app.output())),
                    KeyCode::Esc | KeyCode::Char('q') => return Ok(None),
                    _ => {}
                }
            }
            Event::Mouse(m) => match m.kind {
                MouseEventKind::ScrollUp => app.move_cursor(-1),
                MouseEventKind::ScrollDown => app.move_cursor(1),
                MouseEventKind::Down(MouseButton::Left) => {
                    let pos = Position::new(m.column, m.row);
                    if app.ok_rect.contains(pos) {
                        return Ok(Some(app.output()));
                    }
                    if app.cancel_rect.contains(pos) {
                        return Ok(None);
                    }
                    if app.list_rect.contains(pos) {
                        let idx =
                            app.list_state.offset() + (m.row - app.list_rect.y) as usize;
                        if idx < app.items.len() {
                            if app.checklist {
                                app.cursor = idx;
                                app.items[idx].on = !app.items[idx].on;
                            } else if idx == app.cursor {
                                return Ok(Some(app.output())); // second click = OK
                            } else {
                                app.cursor = idx;
                            }
                        }
                    }
                }
                _ => {}
            },
            Event::Resize(_, _) => {} // loop redraws
            _ => {}
        }
    }
}

fn restore_terminal() {
    let _ = disable_raw_mode();
    let _ = execute!(io::stderr(), LeaveAlternateScreen, DisableMouseCapture);
}

fn main() -> io::Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let cmd = match parse_args(&args) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("aicli-tui: {e}");
            std::process::exit(2);
        }
    };

    let default_hook = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |info| {
        restore_terminal();
        default_hook(info);
    }));

    enable_raw_mode()?;
    execute!(io::stderr(), EnterAlternateScreen, EnableMouseCapture)?;
    let mut terminal = Terminal::new(ratatui::backend::CrosstermBackend::new(io::stderr()))?;

    let mut app = App::new(cmd);
    let result = run_app(&mut terminal, &mut app);
    restore_terminal();

    match result? {
        Some(lines) => {
            let mut out = io::stdout();
            for line in lines {
                writeln!(out, "{line}")?;
            }
            Ok(())
        }
        None => std::process::exit(1),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn v(s: &[&str]) -> Vec<String> {
        s.iter().map(|x| x.to_string()).collect()
    }

    #[test]
    fn valid_checklist() {
        let cmd = parse_args(&v(&["checklist", "Pick", "a", "Alpha", "ON", "b", "Beta", "OFF"]))
            .expect("should parse");
        match cmd {
            Cmd::Checklist { title, items } => {
                assert_eq!(title, "Pick");
                assert_eq!(items.len(), 2);
                assert_eq!(items[0], Item { tag: "a".into(), desc: "Alpha".into(), on: true });
                assert!(!items[1].on);
            }
            _ => panic!("wrong variant"),
        }
    }

    #[test]
    fn valid_menu() {
        let cmd = parse_args(&v(&["menu", "Choose", "x", "Ex", "y", "Why"])).expect("should parse");
        match cmd {
            Cmd::Menu { title, items } => {
                assert_eq!(title, "Choose");
                assert_eq!(items.len(), 2);
                assert_eq!(items[1].tag, "y");
            }
            _ => panic!("wrong variant"),
        }
    }

    #[test]
    fn bad_args() {
        assert!(parse_args(&v(&["checklist", "T", "a", "Alpha", "MAYBE"])).is_err()); // bad state
        assert!(parse_args(&v(&["checklist", "T", "a", "Alpha"])).is_err()); // not triples
        assert!(parse_args(&v(&["menu", "T", "a"])).is_err()); // not pairs
        assert!(parse_args(&v(&["menu", "T"])).is_err()); // no items
        assert!(parse_args(&v(&["bogus"])).is_err());
        assert!(parse_args(&[]).is_err());
    }
}
