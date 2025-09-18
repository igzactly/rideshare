# Dissertation Formatting Guide

## Document Structure and Formatting Requirements

### General Formatting Guidelines

#### Page Setup
- **Page Size:** A4 (210 × 297 mm)
- **Margins:** 
  - Left: 1.5 inches (3.8 cm) - for binding
  - Right: 1 inch (2.5 cm)
  - Top: 1 inch (2.5 cm)
  - Bottom: 1 inch (2.5 cm)
- **Line Spacing:** Double-spaced throughout (except for block quotes, footnotes, and references)
- **Font:** Times New Roman, 12-point
- **Page Numbers:** Bottom center, starting from the Introduction (Arabic numerals)

#### Preliminary Pages Formatting
- **Title Page:** No page number
- **Abstract:** Roman numerals (i, ii, iii, etc.)
- **Table of Contents:** Roman numerals
- **List of Figures/Tables:** Roman numerals (if applicable)

### Chapter Formatting

#### Chapter Headings
- **Format:** Centered, Bold, Title Case
- **Font Size:** 14-point
- **Spacing:** Triple space before, double space after
- **Page Break:** Each chapter starts on a new page

#### Section Headings
- **Level 1 (1.1):** Left-aligned, Bold, Title Case, 12-point
- **Level 2 (1.1.1):** Left-aligned, Bold, Sentence case, 12-point
- **Level 3 (1.1.1.1):** Left-aligned, Italic, Sentence case, 12-point

#### Paragraph Formatting
- **Indentation:** First line indented 0.5 inches
- **Alignment:** Justified
- **Spacing:** Double-spaced
- **Orphans/Widows:** Avoid single lines at top/bottom of pages

### Tables and Figures

#### Table Formatting
```
Table 1.1: Performance Metrics Summary

| Metric          | Target    | Achieved  | Status |
|----------------|-----------|-----------|--------|
| Response Time  | <200ms    | 180ms     | ✓      |
| Uptime         | 99.9%     | 99.95%    | ✓      |
| Throughput     | 1000 RPS  | 1200 RPS  | ✓      |

Note: All metrics measured over 30-day period.
```

#### Figure Formatting
```
[THIS IS FIGURE: System Architecture Diagram showing the relationship between mobile applications, API gateway, and database components]

Figure 3.1: Overall system architecture of the rideshare platform
```

#### Caption Guidelines
- **Tables:** Caption above the table (Table X.X: Description)
- **Figures:** Caption below the figure (Figure X.X: Description)
- **Numbering:** Sequential within each chapter (1.1, 1.2, 2.1, 2.2, etc.)

### Code Formatting

#### Inline Code
Use `backticks` for inline code references, variable names, and short code snippets.

#### Code Blocks
```python
# Example API endpoint implementation
@app.route('/api/trips', methods=['POST'])
def create_trip():
    """Create a new trip request."""
    data = request.get_json()
    trip = Trip(
        passenger_id=data['passenger_id'],
        pickup_location=data['pickup_location'],
        destination=data['destination']
    )
    db.session.add(trip)
    db.session.commit()
    return jsonify(trip.to_dict()), 201
```

#### Code Citation Format
```python
# File: app/routes/trips.py, Lines 45-58
def calculate_fare(distance, duration):
    """Calculate trip fare based on distance and time."""
    base_fare = 2.50
    distance_rate = 1.20  # per mile
    time_rate = 0.25     # per minute
    
    return base_fare + (distance * distance_rate) + (duration * time_rate)
```

### Citation and Reference Formatting

#### In-Text Citations (APA Style)
- **Single author:** (Smith, 2023)
- **Two authors:** (Smith & Johnson, 2023)
- **Multiple authors:** (Smith et al., 2023)
- **Multiple works:** (Smith, 2023; Johnson, 2022)
- **Direct quote:** (Smith, 2023, p. 45)

#### Reference List Format
**Books:**
```
Gamma, E., Helm, R., Johnson, R., & Vlissides, J. (1994). Design patterns: Elements of reusable object-oriented software. Addison-Wesley Professional.
```

**Journal Articles:**
```
Smith, J. A., & Brown, M. K. (2023). Scalable architecture patterns for mobile applications. Journal of Software Engineering, 45(3), 123-145. https://doi.org/10.1000/xyz123
```

**Web Sources:**
```
Flutter Team. (2023). Flutter documentation. Flutter. https://flutter.dev/docs
```

### Mathematical Notation

#### Inline Math
Use \( and \) for inline mathematical expressions: \(E = mc^2\)

#### Block Math
Use \[ and \] for block mathematical expressions:
\[
\text{Response Time} = \frac{\text{Total Processing Time}}{\text{Number of Requests}}
\]

### Appendices Formatting

#### Appendix Structure
```
Appendix A: System Requirements Specification
Appendix B: API Documentation
Appendix C: Database Schema
Appendix D: Deployment Guides
```

#### Appendix Content
- Each appendix starts on a new page
- Use same formatting as main chapters
- Number sections within appendices (A.1, A.2, B.1, B.2, etc.)

### Quality Checklist

#### Content Review
- [ ] All chapters complete and properly structured
- [ ] Consistent terminology throughout
- [ ] Proper transitions between sections
- [ ] Academic tone maintained
- [ ] Technical accuracy verified

#### Formatting Review
- [ ] Consistent heading styles
- [ ] Proper page numbering
- [ ] Correct margins and spacing
- [ ] Table and figure captions formatted correctly
- [ ] Code blocks properly formatted
- [ ] Citations follow APA style
- [ ] Reference list alphabetically ordered

#### Technical Review
- [ ] All code examples tested and functional
- [ ] Screenshots and diagrams clear and relevant
- [ ] API documentation accurate
- [ ] Database schemas validated
- [ ] Deployment instructions verified

### Common Formatting Errors to Avoid

1. **Inconsistent Heading Styles**
   - Ensure all headings at the same level use identical formatting
   - Maintain consistent capitalization (Title Case vs. Sentence case)

2. **Improper Code Formatting**
   - Don't use proportional fonts for code
   - Maintain consistent indentation
   - Include proper syntax highlighting

3. **Citation Errors**
   - Missing page numbers for direct quotes
   - Inconsistent citation format
   - Missing entries in reference list

4. **Table and Figure Issues**
   - Inconsistent caption placement
   - Missing or incorrect numbering
   - Poor quality images or diagrams

5. **Spacing Problems**
   - Inconsistent line spacing
   - Improper paragraph indentation
   - Too much or too little white space

### Tools and Software Recommendations

#### Writing and Formatting
- **Microsoft Word** - Built-in dissertation templates
- **LaTeX** - Professional typesetting system
- **Google Docs** - Collaborative editing
- **Grammarly** - Grammar and style checking

#### Reference Management
- **Zotero** - Free reference manager
- **Mendeley** - Academic reference tool
- **EndNote** - Professional reference software

#### Diagram Creation
- **Lucidchart** - Professional diagramming
- **Draw.io** - Free online diagramming
- **Visio** - Microsoft diagramming tool

#### Code Documentation
- **Sphinx** - Python documentation generator
- **GitBook** - Modern documentation platform
- **Notion** - All-in-one workspace

### Final Submission Requirements

#### Print Version
- High-quality paper (20lb minimum)
- Professional binding (spiral or perfect bound)
- Clear, readable printing
- All pages included in correct order

#### Digital Version
- PDF format with embedded fonts
- Bookmarks for easy navigation
- Searchable text (not scanned images)
- File size optimized for upload

#### Supplementary Materials
- Source code repository (GitHub/GitLab)
- Data files and datasets
- Video demonstrations (if applicable)
- Deployment scripts and documentation

---

**Note:** Always verify specific formatting requirements with your institution's dissertation guidelines, as requirements may vary between universities and departments.