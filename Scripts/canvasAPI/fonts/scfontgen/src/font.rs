use fontdue;

use std::fs;
use std::path::*;
use std::u8;
use std::string::String;

fn gen_ascii(start: char, end: char) -> String {
    let mut result = String::new();
    for c in start..=end {
        result.push(c);
    }
    return result;
}

fn parse(path: &Path, px: f32, contrast:u8, charmaps: &Vec<String>, name: &String) -> String {
    let font = fs::read(path).unwrap();
    let font = font.as_slice();
    let font = fontdue::Font::from_bytes(font, fontdue::FontSettings::default()).unwrap();

    let mut out = String::new();
    out.push_str("-- ScrapMechanic canvasAPI font\n-- name - ");
    out.push_str(name);
    out.push_str("\n-- size - ");
    out.push_str(&px.to_string());
    out.push_str("\n\nfont.fonts.");
    out.push_str(name);
    out.push_str("={mono=false,chars={");

    let mut char_added = false;
    for charmap in charmaps {
        for (_i, c) in charmap.chars().enumerate() {
            let (metrics, bitmap) = font.rasterize(c, px);

            if metrics.width == 0 || metrics.height == 0 {
                continue;
            }

            if char_added {
                out.push_str(",");
            }

            out.push_str("[\"");
            if c == '"' {
                out.push_str("\\\"");
            } else if c == '\\' {
                out.push_str("\\\\");
            } else {
                out.push_str(&c.to_string());
            }
            out.push_str("\"]={");

            //out.push(c as u8);
            //out.push((metrics.width >> 8) as u8);
            //out.push((metrics.width & 0xff) as u8);
            //out.push((metrics.height >> 8) as u8);
            //out.push((metrics.height & 0xff) as u8);

            //let mut write_byte: u8 = 0;

            let mut char_added2 = false;
            let add_width = metrics.xmin;
            let add_height = metrics.ymin;
            for py in 0..metrics.height {
                let mut lstr = String::new();
                for px in 0..metrics.width {
                    if bitmap[px + (py * metrics.width)] > contrast {
                        lstr += "1";
                    } else {
                        lstr += ".";
                    }
                }

                if char_added2 {
                    out.push_str(",");
                }
                out.push_str("\"");
                out.push_str(&lstr);
                out.push_str("\"");
                char_added2 = true;
            }

            out.push_str(",width = ");
            out.push_str(&metrics.width.to_string());
            out.push_str(",");
            out.push_str("height=");
            out.push_str(&metrics.height.to_string());

            out.push_str(",offsetX=");
            out.push_str(&add_width.to_string());
            out.push_str(",offsetY=");
            out.push_str(&add_height.to_string());
            out.push_str("}");
            char_added = true;
        }
    }

    out.push_str("}}\n\nfont.fonts.");
    out.push_str(name);
    out.push_str(".index = font.fontIndex\n");
    out.push_str("font.fonts[font.fontIndex] = font.fonts.");
    out.push_str(name);
    out.push_str("\nfont.fontIndex = font.fontIndex + 1\n");

    return out;
}

pub fn process_font(path: &Path, contrast: u8, px: f32) -> String {
    let name = path.with_extension("").file_name().unwrap().to_str().unwrap().to_string();
    let new_name = format!("{}_{}", name, px.floor());

    let mut charmaps: Vec<String> = Vec::new();
    charmaps.push(String::from(gen_ascii('!', '~')));
    charmaps.push(String::from("абвгдеёжзийклмнопрстуфхцчшщьыъэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЬЫЪЭЮЯ"));

    let parsed_font = parse(&path, px, contrast, &charmaps, &new_name);
    let converted_path = format!("../converted/{}.lua", new_name);
    let save_path = Path::new(converted_path.as_str());
    fs::write(&save_path, &parsed_font).expect("failed to write");
    return save_path.file_name().unwrap().to_str().unwrap().to_string();
}

fn process_font_with_size(fonts_file: &String, path: &Path, size: i32) -> String {
    let mut contrast = 200;
    if size <= 16 {
        contrast = 180;
    }
    let str = process_font(path, contrast, size as f32);
    let mut fonts_file = fonts_file.clone();
    fonts_file.push_str(format!("dofile(\"$CONTENT_DATA/Scripts/canvasAPI/fonts/converted/{}\")\n", str).as_str());
    return fonts_file;
}

pub fn process_font_all(path: &Path) -> String {
    println!("process_font_all: {}", path.to_str().unwrap().to_string());
    let mut fonts_file = String::new();
    fonts_file = process_font_with_size(&fonts_file, path, 16);
    fonts_file = process_font_with_size(&fonts_file, path, 32);
    fonts_file = process_font_with_size(&fonts_file, path, 72);
    return fonts_file;
}