use anyhow::{bail, Context};
use std::fs::File;
use std::io::{BufReader, Read, Seek, SeekFrom};
use std::path::Path;

/// Iterates top-level entries of a large JSON object `{ "key": { ... }, ... }` without
/// loading the full file into memory.
pub fn for_each_top_level_object_entry<F>(path: &Path, mut f: F) -> anyhow::Result<()>
where
    F: FnMut(&str, &str) -> anyhow::Result<()>,
{
    let file = File::open(path).with_context(|| format!("open weather fixture {}", path.display()))?;
    let mut reader = BufReader::new(file);
    skip_ws(&mut reader)?;
    expect_byte(&mut reader, b'{')?;

    loop {
        skip_ws(&mut reader)?;
        if peek_byte(&mut reader)? == b'}' {
            reader.read_exact(&mut [0u8; 1])?;
            break;
        }
        let key = read_json_string(&mut reader)?;
        skip_ws(&mut reader)?;
        expect_byte(&mut reader, b':')?;
        skip_ws(&mut reader)?;
        let value_json = read_json_value(&mut reader)?;
        f(&key, &value_json)?;
        skip_ws(&mut reader)?;
        if peek_byte(&mut reader)? == b',' {
            reader.read_exact(&mut [0u8; 1])?;
        }
    }
    Ok(())
}

fn peek_byte<R: Read + Seek>(reader: &mut R) -> anyhow::Result<u8> {
    let b = {
        let mut buf = [0u8; 1];
        reader.read_exact(&mut buf)?;
        buf[0]
    };
    reader.seek(SeekFrom::Current(-1))?;
    Ok(b)
}

fn expect_byte<R: Read>(reader: &mut R, expected: u8) -> anyhow::Result<()> {
    let mut buf = [0u8; 1];
    reader.read_exact(&mut buf)?;
    if buf[0] != expected {
        bail!("expected JSON byte {expected}, got {}", buf[0]);
    }
    Ok(())
}

fn skip_ws<R: Read + Seek>(reader: &mut R) -> anyhow::Result<()> {
    loop {
        let b = peek_byte(reader)?;
        if b.is_ascii_whitespace() {
            reader.read_exact(&mut [0u8; 1])?;
        } else {
            break;
        }
    }
    Ok(())
}

fn read_json_string<R: Read>(reader: &mut R) -> anyhow::Result<String> {
    expect_byte(reader, b'"')?;
    let mut out = String::new();
    loop {
        let mut buf = [0u8; 1];
        reader.read_exact(&mut buf)?;
        match buf[0] {
            b'"' => break,
            b'\\' => {
                reader.read_exact(&mut buf)?;
                match buf[0] {
                    b'"' | b'\\' | b'/' => out.push(buf[0] as char),
                    b'b' => out.push('\u{0008}'),
                    b'f' => out.push('\u{000C}'),
                    b'n' => out.push('\n'),
                    b'r' => out.push('\r'),
                    b't' => out.push('\t'),
                    b'u' => {
                        let mut hex = [0u8; 4];
                        reader.read_exact(&mut hex)?;
                        let code = u16::from_str_radix(
                            std::str::from_utf8(&hex).context("unicode escape")?,
                            16,
                        )?;
                        if let Some(c) = char::from_u32(code as u32) {
                            out.push(c);
                        } else {
                            bail!("invalid unicode escape");
                        }
                    }
                    _ => bail!("invalid JSON escape"),
                }
            }
            b => out.push(b as char),
        }
    }
    Ok(out)
}

fn read_json_value<R: Read + Seek>(reader: &mut R) -> anyhow::Result<String> {
    let start = match peek_byte(reader)? {
        b'{' => read_balanced(reader, b'{', b'}')?,
        b'[' => read_balanced(reader, b'[', b']')?,
        b'"' => {
            let s = read_json_string(reader)?;
            serde_json::to_string(&s)?
        }
        b't' | b'f' | b'n' => read_primitive_token(reader)?,
        b'0'..=b'9' | b'-' => read_primitive_token(reader)?,
        other => bail!("unexpected JSON value start: {other}"),
    };
    Ok(start)
}

fn read_balanced<R: Read + Seek>(reader: &mut R, open: u8, close: u8) -> anyhow::Result<String> {
    let mut depth = 0i32;
    let mut in_string = false;
    let mut escape = false;
    let mut out = Vec::new();

    loop {
        let mut buf = [0u8; 1];
        reader.read_exact(&mut buf)?;
        let b = buf[0];
        out.push(b);

        if in_string {
            if escape {
                escape = false;
            } else if b == b'\\' {
                escape = true;
            } else if b == b'"' {
                in_string = false;
            }
            continue;
        }

        match b {
            b'"' => in_string = true,
            c if c == open => depth += 1,
            c if c == close => {
                depth -= 1;
                if depth == 0 {
                    break;
                }
            }
            _ => {}
        }
    }

    Ok(String::from_utf8(out).context("weather JSON value utf8")?)
}

fn read_primitive_token<R: Read + Seek>(reader: &mut R) -> anyhow::Result<String> {
    let mut out = Vec::new();
    loop {
        let b = peek_byte(reader)?;
        if b == b',' || b == b'}' || b == b']' || b.is_ascii_whitespace() {
            break;
        }
        let mut buf = [0u8; 1];
        reader.read_exact(&mut buf)?;
        out.push(buf[0]);
    }
    Ok(String::from_utf8(out).context("primitive token utf8")?)
}
