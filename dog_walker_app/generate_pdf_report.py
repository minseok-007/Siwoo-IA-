#!/usr/bin/env python3
"""
PDF Report Generator for IB Computer Science HL Criterion C Report
Converts the Markdown report to a professionally formatted PDF
"""

import markdown
import pdfkit
from pathlib import Path
import re

def convert_markdown_to_pdf():
    """Convert the Markdown report to PDF with proper formatting"""
    
    # Read the markdown file
    markdown_file = Path("IB_CS_HL_Criterion_C_Report.md")
    
    if not markdown_file.exists():
        print(f"Error: {markdown_file} not found!")
        return False
    
    with open(markdown_file, 'r', encoding='utf-8') as f:
        markdown_content = f.read()
    
    # Convert markdown to HTML
    html = markdown.markdown(markdown_content, extensions=[
        'markdown.extensions.tables',
        'markdown.extensions.fenced_code',
        'markdown.extensions.toc',
        'markdown.extensions.codehilite'
    ])
    
    # Create a complete HTML document with CSS styling
    html_document = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>IB Computer Science HL - Criterion C Report</title>
        <style>
            body {{
                font-family: 'Times New Roman', serif;
                line-height: 1.6;
                margin: 40px;
                color: #333;
            }}
            
            h1 {{
                color: #2c3e50;
                border-bottom: 3px solid #3498db;
                padding-bottom: 10px;
                page-break-before: always;
            }}
            
            h1:first-child {{
                page-break-before: auto;
            }}
            
            h2 {{
                color: #34495e;
                border-bottom: 2px solid #ecf0f1;
                padding-bottom: 5px;
                margin-top: 30px;
            }}
            
            h3 {{
                color: #7f8c8d;
                margin-top: 25px;
            }}
            
            h4 {{
                color: #95a5a6;
                margin-top: 20px;
            }}
            
            code {{
                background-color: #f8f9fa;
                border: 1px solid #e9ecef;
                border-radius: 3px;
                padding: 2px 4px;
                font-family: 'Courier New', monospace;
                font-size: 0.9em;
            }}
            
            pre {{
                background-color: #f8f9fa;
                border: 1px solid #e9ecef;
                border-radius: 5px;
                padding: 15px;
                overflow-x: auto;
                margin: 15px 0;
            }}
            
            pre code {{
                background: none;
                border: none;
                padding: 0;
            }}
            
            table {{
                border-collapse: collapse;
                width: 100%;
                margin: 20px 0;
            }}
            
            th, td {{
                border: 1px solid #ddd;
                padding: 12px;
                text-align: left;
            }}
            
            th {{
                background-color: #f2f2f2;
                font-weight: bold;
            }}
            
            tr:nth-child(even) {{
                background-color: #f9f9f9;
            }}
            
            .algorithm-complexity {{
                background-color: #e8f5e8;
                border-left: 4px solid #27ae60;
                padding: 10px;
                margin: 10px 0;
            }}
            
            .code-explanation {{
                background-color: #fff3cd;
                border-left: 4px solid #ffc107;
                padding: 10px;
                margin: 10px 0;
            }}
            
            .performance-metric {{
                background-color: #d1ecf1;
                border-left: 4px solid #17a2b8;
                padding: 10px;
                margin: 10px 0;
            }}
            
            .page-break {{
                page-break-before: always;
            }}
            
            .no-break {{
                page-break-inside: avoid;
            }}
            
            ul, ol {{
                margin: 15px 0;
                padding-left: 30px;
            }}
            
            li {{
                margin: 5px 0;
            }}
            
            blockquote {{
                border-left: 4px solid #3498db;
                margin: 20px 0;
                padding: 10px 20px;
                background-color: #f8f9fa;
            }}
            
            .toc {{
                background-color: #f8f9fa;
                border: 1px solid #e9ecef;
                border-radius: 5px;
                padding: 20px;
                margin: 20px 0;
            }}
            
            .toc h2 {{
                margin-top: 0;
                color: #2c3e50;
            }}
            
            .toc ul {{
                list-style-type: none;
                padding-left: 0;
            }}
            
            .toc li {{
                margin: 5px 0;
            }}
            
            .toc a {{
                text-decoration: none;
                color: #3498db;
            }}
            
            .toc a:hover {{
                text-decoration: underline;
            }}
            
            @media print {{
                body {{
                    margin: 20px;
                }}
                
                h1, h2, h3, h4 {{
                    page-break-after: avoid;
                }}
                
                pre, blockquote {{
                    page-break-inside: avoid;
                }}
                
                table {{
                    page-break-inside: avoid;
                }}
            }}
        </style>
    </head>
    <body>
        {html}
    </body>
    </html>
    """
    
    # Configure PDF options
    options = {
        'page-size': 'A4',
        'margin-top': '1in',
        'margin-right': '1in',
        'margin-bottom': '1in',
        'margin-left': '1in',
        'encoding': "UTF-8",
        'no-outline': None,
        'enable-local-file-access': None,
        'print-media-type': None,
        'dpi': 300,
    }
    
    # Generate PDF
    try:
        pdfkit.from_string(html_document, 'IB_CS_HL_Criterion_C_Report.pdf', options=options)
        print("✅ PDF report generated successfully: IB_CS_HL_Criterion_C_Report.pdf")
        return True
    except Exception as e:
        print(f"❌ Error generating PDF: {e}")
        print("\nNote: You may need to install wkhtmltopdf:")
        print("  - macOS: brew install wkhtmltopdf")
        print("  - Ubuntu: sudo apt-get install wkhtmltopdf")
        print("  - Windows: Download from https://wkhtmltopdf.org/downloads.html")
        return False

def create_simplified_pdf():
    """Create a simplified PDF using basic HTML if wkhtmltopdf is not available"""
    
    markdown_file = Path("IB_CS_HL_Criterion_C_Report.md")
    
    if not markdown_file.exists():
        print(f"Error: {markdown_file} not found!")
        return False
    
    with open(markdown_file, 'r', encoding='utf-8') as f:
        markdown_content = f.read()
    
    # Convert markdown to HTML
    html = markdown.markdown(markdown_content, extensions=[
        'markdown.extensions.tables',
        'markdown.extensions.fenced_code',
        'markdown.extensions.toc',
        'markdown.extensions.codehilite'
    ])
    
    # Create a simple HTML document
    html_document = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>IB Computer Science HL - Criterion C Report</title>
        <style>
            body {{ font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }}
            h1 {{ color: #2c3e50; border-bottom: 2px solid #3498db; }}
            h2 {{ color: #34495e; border-bottom: 1px solid #ecf0f1; }}
            code {{ background-color: #f8f9fa; padding: 2px 4px; border-radius: 3px; }}
            pre {{ background-color: #f8f9fa; padding: 15px; border-radius: 5px; overflow-x: auto; }}
            table {{ border-collapse: collapse; width: 100%; margin: 20px 0; }}
            th, td {{ border: 1px solid #ddd; padding: 12px; text-align: left; }}
            th {{ background-color: #f2f2f2; }}
        </style>
    </head>
    <body>
        {html}
    </body>
    </html>
    """
    
    # Save as HTML file
    with open('IB_CS_HL_Criterion_C_Report.html', 'w', encoding='utf-8') as f:
        f.write(html_document)
    
    print("✅ HTML report generated: IB_CS_HL_Criterion_C_Report.html")
    print("   You can open this file in a web browser and print to PDF")
    return True

if __name__ == "__main__":
    print("🔄 Generating IB Computer Science HL Criterion C Report...")
    
    # Try to generate PDF with wkhtmltopdf
    if convert_markdown_to_pdf():
        print("\n📄 Report successfully converted to PDF!")
        print("   File: IB_CS_HL_Criterion_C_Report.pdf")
    else:
        print("\n⚠️  PDF generation failed, creating HTML version instead...")
        create_simplified_pdf()
        print("\n📄 HTML report created!")
        print("   File: IB_CS_HL_Criterion_C_Report.html")
        print("   You can open this in a browser and print to PDF")
    
    print("\n✨ Report generation complete!")