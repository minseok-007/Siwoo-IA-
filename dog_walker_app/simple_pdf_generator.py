#!/usr/bin/env python3
"""
Simple PDF Generator for IB Computer Science HL Criterion C Report
Uses weasyprint for better PDF generation
"""

import markdown
import os
from pathlib import Path

def convert_markdown_to_html():
    """Convert the Markdown report to HTML with proper formatting"""
    
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
            @page {{
                size: A4;
                margin: 2.5cm;
            }}
            
            body {{
                font-family: 'Times New Roman', serif;
                line-height: 1.6;
                color: #333;
                font-size: 12pt;
            }}
            
            h1 {{
                color: #2c3e50;
                border-bottom: 3px solid #3498db;
                padding-bottom: 10px;
                page-break-before: always;
                font-size: 18pt;
                margin-top: 0;
            }}
            
            h1:first-child {{
                page-break-before: auto;
            }}
            
            h2 {{
                color: #34495e;
                border-bottom: 2px solid #ecf0f1;
                padding-bottom: 5px;
                margin-top: 30px;
                font-size: 16pt;
            }}
            
            h3 {{
                color: #7f8c8d;
                margin-top: 25px;
                font-size: 14pt;
            }}
            
            h4 {{
                color: #95a5a6;
                margin-top: 20px;
                font-size: 13pt;
            }}
            
            code {{
                background-color: #f8f9fa;
                border: 1px solid #e9ecef;
                border-radius: 3px;
                padding: 2px 4px;
                font-family: 'Courier New', monospace;
                font-size: 10pt;
            }}
            
            pre {{
                background-color: #f8f9fa;
                border: 1px solid #e9ecef;
                border-radius: 5px;
                padding: 15px;
                overflow-x: auto;
                margin: 15px 0;
                font-family: 'Courier New', monospace;
                font-size: 10pt;
                page-break-inside: avoid;
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
                font-size: 11pt;
                page-break-inside: avoid;
            }}
            
            th, td {{
                border: 1px solid #ddd;
                padding: 8px;
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
                page-break-inside: avoid;
            }}
            
            .code-explanation {{
                background-color: #fff3cd;
                border-left: 4px solid #ffc107;
                padding: 10px;
                margin: 10px 0;
                page-break-inside: avoid;
            }}
            
            .performance-metric {{
                background-color: #d1ecf1;
                border-left: 4px solid #17a2b8;
                padding: 10px;
                margin: 10px 0;
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
                page-break-inside: avoid;
            }}
            
            .toc {{
                background-color: #f8f9fa;
                border: 1px solid #e9ecef;
                border-radius: 5px;
                padding: 20px;
                margin: 20px 0;
                page-break-inside: avoid;
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
            
            .page-break {{
                page-break-before: always;
            }}
            
            .no-break {{
                page-break-inside: avoid;
            }}
            
            @media print {{
                body {{
                    margin: 0;
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
    
    # Save HTML file
    with open('IB_CS_HL_Criterion_C_Report.html', 'w', encoding='utf-8') as f:
        f.write(html_document)
    
    print("✅ HTML report generated: IB_CS_HL_Criterion_C_Report.html")
    return True

def create_simple_html():
    """Create a simple HTML version for easy printing"""
    
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
    
    # Create a simple HTML document optimized for printing
    html_document = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>IB Computer Science HL - Criterion C Report</title>
        <style>
            @media print {{
                @page {{
                    size: A4;
                    margin: 2cm;
                }}
                
                body {{
                    font-family: 'Times New Roman', serif;
                    font-size: 12pt;
                    line-height: 1.5;
                    color: #000;
                }}
                
                h1 {{
                    font-size: 18pt;
                    color: #000;
                    border-bottom: 2px solid #000;
                    page-break-before: always;
                    margin-top: 0;
                }}
                
                h1:first-child {{
                    page-break-before: auto;
                }}
                
                h2 {{
                    font-size: 16pt;
                    color: #000;
                    border-bottom: 1px solid #000;
                    margin-top: 20pt;
                }}
                
                h3 {{
                    font-size: 14pt;
                    color: #000;
                    margin-top: 15pt;
                }}
                
                h4 {{
                    font-size: 13pt;
                    color: #000;
                    margin-top: 10pt;
                }}
                
                code {{
                    font-family: 'Courier New', monospace;
                    font-size: 10pt;
                    background-color: #f5f5f5;
                    padding: 1px 3px;
                }}
                
                pre {{
                    font-family: 'Courier New', monospace;
                    font-size: 9pt;
                    background-color: #f5f5f5;
                    padding: 10pt;
                    border: 1px solid #ccc;
                    page-break-inside: avoid;
                    overflow-x: auto;
                }}
                
                table {{
                    border-collapse: collapse;
                    width: 100%;
                    font-size: 10pt;
                    page-break-inside: avoid;
                }}
                
                th, td {{
                    border: 1px solid #000;
                    padding: 5pt;
                    text-align: left;
                }}
                
                th {{
                    background-color: #f0f0f0;
                    font-weight: bold;
                }}
                
                ul, ol {{
                    margin: 10pt 0;
                    padding-left: 20pt;
                }}
                
                li {{
                    margin: 3pt 0;
                }}
                
                blockquote {{
                    border-left: 3px solid #000;
                    margin: 10pt 0;
                    padding: 5pt 10pt;
                    background-color: #f9f9f9;
                }}
            }}
            
            @media screen {{
                body {{
                    font-family: Arial, sans-serif;
                    max-width: 800px;
                    margin: 0 auto;
                    padding: 20px;
                    line-height: 1.6;
                }}
                
                h1 {{
                    color: #2c3e50;
                    border-bottom: 3px solid #3498db;
                }}
                
                h2 {{
                    color: #34495e;
                    border-bottom: 2px solid #ecf0f1;
                }}
                
                code {{
                    background-color: #f8f9fa;
                    padding: 2px 4px;
                    border-radius: 3px;
                }}
                
                pre {{
                    background-color: #f8f9fa;
                    padding: 15px;
                    border-radius: 5px;
                    overflow-x: auto;
                }}
                
                table {{
                    border-collapse: collapse;
                    width: 100%;
                }}
                
                th, td {{
                    border: 1px solid #ddd;
                    padding: 8px;
                    text-align: left;
                }}
                
                th {{
                    background-color: #f2f2f2;
                }}
            }}
        </style>
    </head>
    <body>
        {html}
    </body>
    </html>
    """
    
    # Save HTML file
    with open('IB_CS_HL_Criterion_C_Report_Print.html', 'w', encoding='utf-8') as f:
        f.write(html_document)
    
    print("✅ Print-optimized HTML report generated: IB_CS_HL_Criterion_C_Report_Print.html")
    return True

if __name__ == "__main__":
    print("🔄 Generating IB Computer Science HL Criterion C Report...")
    
    # Generate HTML versions
    if convert_markdown_to_html():
        print("✅ Standard HTML report created!")
    
    if create_simple_html():
        print("✅ Print-optimized HTML report created!")
    
    print("\n📄 Reports generated successfully!")
    print("   Files created:")
    print("   - IB_CS_HL_Criterion_C_Report.html (standard version)")
    print("   - IB_CS_HL_Criterion_C_Report_Print.html (print-optimized)")
    print("\n💡 To convert to PDF:")
    print("   1. Open either HTML file in a web browser")
    print("   2. Press Ctrl+P (or Cmd+P on Mac)")
    print("   3. Select 'Save as PDF' as destination")
    print("   4. Choose 'More settings' and set margins to 'Minimum'")
    print("   5. Click 'Save'")
    
    print("\n✨ Report generation complete!")