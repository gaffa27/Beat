//
//  BeatEditorFormatting.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.2.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

/*

 This class handles formatting the screenplay in editor view
 
 */

#import <BeatParsing/BeatParsing.h>
#import <BeatThemes/BeatThemes.h>
#import <BeatCore/BeatCore.h>
#import <BeatPagination2/BeatPagination2-Swift.h>

#import "BeatEditorFormatting.h"
//#import "Beat-Swift.h"
//#import "BeatMeasure.h"
#import "NSFont+CFTraits.h"

@interface BeatEditorFormatting()
// Paragraph styles are stored as { @(paperSize): { @(type): style } }
@property (nonatomic) NSMutableDictionary<NSNumber*, NSMutableDictionary<NSNumber*, NSMutableParagraphStyle*>*>* paragraphStyles;
@end

@implementation BeatEditorFormatting

// Base font settings
#define SECTION_FONT_SIZE 16.0 // base value for section sizes
#define LINE_HEIGHT 1.1

// Set character width
#define CHR_WIDTH 7.25
#define TEXT_INSET_TOP 80

#define DIALOGUE_RIGHT 47 * CHR_WIDTH

#define DD_CHARACTER_INDENT 30 * CHR_WIDTH
#define DD_PARENTHETICAL_INDENT 27 * CHR_WIDTH
#define DUAL_DIALOGUE_INDENT 21 * CHR_WIDTH
#define DD_RIGHT 59 * CHR_WIDTH

#define DD_BLOCK_INDENT 0.0
#define DD_BLOCK_CHARACTER_INDENT 9 * CHR_WIDTH
#define DD_BLOCK_PARENTHETICAL_INDENT 6 * CHR_WIDTH

static NSString *underlinedSymbol = @"_";
static NSString *strikeoutSymbolOpen = @"{{";
static NSString *strikeoutSymbolClose = @"}}";

static NSString* const BeatRepresentedLineKey = @"representedLine";

+ (CGFloat)editorLineHeight {
	return 16.0;
}
+ (CGFloat)characterLeft {
	return BeatRenderStyles.shared.character.marginLeft;
}
+ (CGFloat)dialogueLeft {
	return BeatRenderStyles.shared.dialogue.marginLeft;
}

-(instancetype)init {
	self = [super init];
	
	
	return self;
}

/// Returns paragraph style for given line type
- (NSMutableParagraphStyle*)paragraphStyleForType:(LineType)type {
	Line *tempLine = [Line withString:@"" type:type];
	return [self paragraphStyleFor:tempLine];
}

/// Returns paragraph style for given line
- (NSMutableParagraphStyle*)paragraphStyleFor:(Line*)line {
	if (line == nil) line = [Line withString:@"" type:action];
	
	LineType type = line.type;
	
	// Catch forced character cue
	if (_delegate.characterInputForLine == line && _delegate.characterInput) {
		type = character;
	}
	
	// We need to get left margin here to avoid issues with extended line types
	if (line.isTitlePage) type = titlePageUnknown;
	CGFloat leftMargin = [BeatRenderStyles.editor forElement:[Line typeName:type]].marginLeft;
	
	// Extended types for title page fields and sections
	if (line.isTitlePage && line.titlePageKey.length == 0) {
		type = (LineType)titlePageSubField;
	}
	else if (line.type == section && line.sectionDepth > 1) {
		type = (LineType)subSection;
	}
	
	/*
	// This is an idea for storing paragraph styles, but it doesn't seem to work for forced character cues.
	BeatPaperSize paperSize = self.delegate.pageSize;
	NSNumber* paperSizeKey = @(paperSize);
	NSNumber* typeKey = @(type);
		
	// Create dictionary for page size when needed
	if (_paragraphStyles == nil) _paragraphStyles = NSMutableDictionary.new;
	if (_paragraphStyles[paperSizeKey] == nil) _paragraphStyles[paperSizeKey] = NSMutableDictionary.new;
		
	// The style already exists, return the premade value
	if (_paragraphStyles[paperSizeKey][typeKey] != nil) {
		return _paragraphStyles[paperSizeKey][typeKey];
	}
	*/
	
	NSMutableParagraphStyle *style = NSMutableParagraphStyle.new;
	style.minimumLineHeight = BeatEditorFormatting.editorLineHeight;
	style.firstLineHeadIndent = leftMargin;
	style.headIndent = leftMargin;
	
	// TODO: Need to add calculations for tail indents. This is a mess.
	
	if (type == lyrics || type == centered || type == pageBreak) {
		style.alignment = NSTextAlignmentCenter;
	}
	else if (type == titlePageSubField) {
		style.firstLineHeadIndent = leftMargin * 1.25;
		style.headIndent = leftMargin * 1.25;
	}
	else if (line.isTitlePage) {
		style.firstLineHeadIndent = leftMargin;
		style.headIndent = leftMargin;
	}
	else if (type == transitionLine) {
		style.alignment = NSTextAlignmentRight;
		
	} else if (line.type == parenthetical) {
		style.tailIndent = DIALOGUE_RIGHT;
		
	} else if (line.type == dialogue) {
		style.tailIndent = DIALOGUE_RIGHT;
		
	} else if (line.type == dualDialogueCharacter) {
		style.tailIndent = DD_RIGHT;
		
	} else if (line.type == dualDialogueParenthetical) {
		style.tailIndent = DD_RIGHT;
		
	} else if (line.type == dualDialogue) {
		style.tailIndent = DD_RIGHT;
	}
	else if (type == subSection) {
		style.paragraphSpacingBefore = 20.0;
		style.paragraphSpacing = 0.0;
	}
	else if (type == section) {
		style.paragraphSpacingBefore = 30.0;
		style.paragraphSpacing = 0.0;
	}
	
	//_paragraphStyles[paperSizeKey][typeKey] = style;
	
	return style;
}

- (void)formatLinesInRange:(NSRange)range
{
	NSArray* lines = [_delegate.parser linesInRange:range];
	for (Line* line in lines) {
		[self formatLine:line];
	}
}

/// Formats a single line in editor
- (void)formatLine:(Line*)line
{
	[self formatLine:line firstTime:NO];
}

- (void)formatLine:(Line*)line firstTime:(bool)firstTime
{ @autoreleasepool {
	/*
	 
	 This method uses a mixture of permanent text attributes and temporary attributes
	 to optimize performance.
	 
	 Colors are set using NSLayoutManager's temporary attributes, while everything else
	 is stored into the attributed string in NSTextStorage.
	 
	 */
	
	// SAFETY MEASURES:
	if (line == nil) return; // Don't do anything if the line is null
	if (line.position + line.string.length > _delegate.text.length) return; // Don't go out of range
	
	NSRange range = line.textRange;
	
	NSLayoutManager *layoutMgr = _delegate.layoutManager;
	NSTextStorage *textStorage = _delegate.textStorage;
	ThemeManager *themeManager = ThemeManager.sharedManager;
	
	NSMutableDictionary *attributes;
	if (firstTime || line.position == _delegate.text.length) attributes = NSMutableDictionary.new;
	else attributes = [textStorage attributesAtIndex:line.position longestEffectiveRange:nil inRange:line.textRange].mutableCopy;
	
	// Store the represented line
	NSRange fullRange = line.range;
	if (NSMaxRange(fullRange) > textStorage.length) fullRange.length--;
	[textStorage addAttribute:BeatRepresentedLineKey value:line range:fullRange];
	
	// Don't overwrite some attributes, such as represented line, revisions or reviews
	[attributes removeObjectForKey:BeatRevisions.attributeKey];
	[attributes removeObjectForKey:BeatReview.attributeKey];
	[attributes removeObjectForKey:BeatRepresentedLineKey];
	
	if (_delegate.disableFormatting) {
		// Only add bare-bones stuff when formatting is disabled
		[layoutMgr addTemporaryAttribute:NSForegroundColorAttributeName value:themeManager.textColor forCharacterRange:line.range];
		
		NSMutableParagraphStyle *paragraphStyle = [self paragraphStyleFor:nil];
		[attributes setValue:paragraphStyle forKey:NSParagraphStyleAttributeName];
		[attributes setValue:_delegate.courier forKey:NSFontAttributeName];
		//[textView setTypingAttributes:attributes];
		
		if (range.length > 0) [textStorage addAttributes:attributes range:range];
		return;
	}
	
	// Apply paragraph styles
	NSMutableParagraphStyle *paragraphStyle = [self paragraphStyleFor:line];
	[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
	
	// Do nothing for already formatted empty lines (except remove the background)
	if (line.type == empty && line.formattedAs == empty && line.string.length == 0 && line != _delegate.characterInputForLine) {
		[layoutMgr addTemporaryAttribute:NSBackgroundColorAttributeName value:NSColor.clearColor forCharacterRange:line.range];
		return;
	}
	
	// Store the type we are formatting for
	line.formattedAs = line.type;
	
	// Extra rules for character cue input
	if (_delegate.characterInput && _delegate.characterInputForLine == line) {
		// Do some extra checks for dual dialogue
		if (line.length && line.lastCharacter == '^') line.type = dualDialogueCharacter;
		else line.type = character;
		
		NSRange selectedRange = _delegate.selectedRange;
		
		// Only do this if we are REALLY typing at this location
		// Foolproof fix for a strange, rare bug which changes multiple
		// lines into character cues and the user is unable to undo the changes
		if (NSMaxRange(range) <= selectedRange.location) {
			[_delegate.textStorage replaceCharactersInRange:range withString:[textStorage.string substringWithRange:range].uppercaseString];
			line.string = line.string.uppercaseString;
			[_delegate setSelectedRange:selectedRange];
			
			// Reset attribute because we have replaced the text
			[layoutMgr addTemporaryAttribute:NSForegroundColorAttributeName value:themeManager.textColor forCharacterRange:line.range];
		}
		
		// IF we are hiding Fountain markup, we'll need to adjust the range to actually modify line break range, too.
		// No idea why.
		if (_delegate.hideFountainMarkup) {
			range = line.range;
			if (line == _delegate.parser.lines.lastObject) range = line.textRange; // Don't go out of range
		}
	}
	
	// Apply font face
	if (line.type == section) {
		// Stylize sections & synopses
		CGFloat size = SECTION_FONT_SIZE - (line.sectionDepth - 1);
		
		// Also, make lower sections a bit smaller
		size = size - line.sectionDepth;
		if (size < 15) size = 15.0;
		
		[attributes setObject:[_delegate sectionFontWithSize:size] forKey:NSFontAttributeName];
		
	}
	else if (line.type == synopse) {
		[attributes setObject:_delegate.synopsisFont forKey:NSFontAttributeName];
	}
	else if (line.type == pageBreak) {
		// Format page break - bold
		[attributes setObject:_delegate.boldCourier forKey:NSFontAttributeName];
		
	}
	else if (line.type == lyrics) {
		// Format lyrics - italic
		[attributes setObject:_delegate.italicCourier forKey:NSFontAttributeName];
	}
	else if (line.type == shot) {
		// Bolded shots
		[attributes setObject:_delegate.boldCourier forKey:NSFontAttributeName];
	}
	else if (attributes[NSFontAttributeName] != _delegate.courier) {
		// Fall back to default (if not set yet)
		[attributes setObject:_delegate.courier forKey:NSFontAttributeName];
	}
	
	
	// Overwrite some values by default
	if (![attributes valueForKey:NSForegroundColorAttributeName]) {
		[attributes setObject:themeManager.textColor forKey:NSForegroundColorAttributeName];
	}
	if (![attributes valueForKey:NSFontAttributeName]) {
		[attributes setObject:_delegate.courier forKey:NSFontAttributeName];
	}
	if (![attributes valueForKey:NSUnderlineStyleAttributeName]) {
		[attributes setObject:@0 forKey:NSUnderlineStyleAttributeName];
	}
	if (![attributes valueForKey:NSStrikethroughStyleAttributeName]) {
		[attributes setObject:@0 forKey:NSStrikethroughStyleAttributeName];
	}
	if (!attributes[NSBackgroundColorAttributeName]) {
		//[attributes setObject:NSColor.clearColor forKey:NSBackgroundColorAttributeName];
		[textStorage addAttribute:NSBackgroundColorAttributeName value:NSColor.clearColor range:range];
	}
		
	// Add selected attributes
	if (range.length > 0) {
		// Line does have content
		[textStorage addAttributes:attributes range:range];
	} else {
		// Line is currently empty. Add attributes ahead.
		if (range.location < textStorage.string.length) {
			range = NSMakeRange(range.location, range.length + 1);
			[textStorage addAttributes:attributes range:range];
		}
	}
	
	// Dual dialogue
	if (line.isDialogue || line.isDualDialogue) {
		// [self renderDualDialogueForLine:line paragraphStyle:paragraphStyle];
	}
	
	// INPUT ATTRIBUTES FOR CARET / CURSOR
	// If we are editing a dialogue block at the end of the document, the line will be empty.
	// If the line is empty, we need to set typing attributes too, to display correct positioning if this is a dialogue block.
	if (line.string.length == 0 && !firstTime && NSLocationInRange(self.delegate.selectedRange.location, line.range)) {
		
		Line* previousLine;
		NSInteger lineIndex = [_delegate.parser.lines indexOfObject:line];

		if (lineIndex > 0 && lineIndex != NSNotFound) previousLine = [_delegate.parser.lines objectAtIndex:lineIndex - 1];
		
		// Keep dialogue input after any dialogue elements
		if (previousLine.isDialogue && previousLine.length > 0) {
			paragraphStyle = [self paragraphStyleForType:dialogue];
		}
		else if (previousLine.isDualDialogue && previousLine.length > 0) {
			paragraphStyle = [self paragraphStyleForType:dualDialogue];
		} else {
			paragraphStyle = [self paragraphStyleFor:line];
		}
		
		[attributes setObject:_delegate.courier forKey:NSFontAttributeName];
		[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
		[_delegate setTypingAttributes:attributes];
	}
	

	[self applyInlineFormatting:line withAttributes:attributes];
	[self setTextColorFor:line];
	[self revisedTextColorFor:line];
} }

- (void)applyInlineFormatting:(Line*)line withAttributes:(NSDictionary*)attributes {
	NSTextStorage *textStorage = _delegate.textStorage;
	
	// Remove underline/strikeout
	if (attributes[NSUnderlineStyleAttributeName] || attributes[NSStrikethroughStyleAttributeName]) {
		// Overwrite strikethrough / underline
		[textStorage addAttribute:NSUnderlineStyleAttributeName value:@0 range:line.textRange];
		[textStorage addAttribute:NSStrikethroughStyleAttributeName value:@0 range:line.textRange];
	}
	
	// Stylize headings according to settings
	if (line.type == heading) {
		if (_delegate.headingStyleBold) [textStorage applyFontTraits:NSBoldFontMask range:line.textRange];
		if (_delegate.headingStyleUnderline) [textStorage addAttribute:NSUnderlineStyleAttributeName value:@1 range:line.textRange];
	}
		
	//Add in bold, underline, italics and other stylization
	[line.italicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		NSRange globalRange = [self globalRangeFromLocalRange:&range inLineAtPosition:line.position];
		[textStorage applyFontTraits:NSItalicFontMask range:globalRange];
	}];
	[line.boldRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		NSRange globalRange = [self globalRangeFromLocalRange:&range inLineAtPosition:line.position];
		[textStorage applyFontTraits:NSBoldFontMask range:globalRange];
	}];
	[line.boldItalicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		NSRange globalRange = [self globalRangeFromLocalRange:&range inLineAtPosition:line.position];
		[textStorage applyFontTraits:NSBoldFontMask | NSItalicFontMask range:globalRange];
	}];
	
	[line.underlinedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self stylize:NSUnderlineStyleAttributeName value:@1 line:line range:range formattingSymbol:underlinedSymbol];
	}];
	[line.strikeoutRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self stylize:NSStrikethroughStyleAttributeName value:@1 line:line range:range formattingSymbol:strikeoutSymbolOpen];
	}];
	
	[textStorage enumerateAttribute:BeatRevisions.attributeKey inRange:line.textRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		BeatRevisionItem* revision = value;
		if (revision.type == RevisionRemovalSuggestion) {
			[textStorage addAttribute:NSStrikethroughStyleAttributeName value:@1 range:range];
			[textStorage addAttribute:NSStrikethroughColorAttributeName value:BeatColors.colors[@"red"] range:range];
		}
	}];
}

#pragma mark - Set foreground color

- (void)setForegroundColor:(NSColor*)color line:(Line*)line range:(NSRange)localRange {
	NSRange globalRange = [self globalRangeFromLocalRange:&localRange inLineAtPosition:line.position];
	
	// Don't go out of range and add attributes
	if (NSMaxRange(localRange) <= line.string.length && localRange.location >= 0 && color != nil) {
		[_delegate.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:color forCharacterRange:globalRange];
	}
	
}

#pragma mark - Render dual dialogue

/// Note that this method modifies the `paragraph` pointer
- (void)renderDualDialogueForLine:(Line*)line paragraphStyle:(NSMutableParagraphStyle*)paragraph
{
	return;
/*
	// An die Nachgeborenen.
	// For future generations.
	 
	bool isDualDialogue = false;
	NSArray* dialogueBlocks = [self.delegate.parser dualDialogueFor:line isDualDialogue:&isDualDialogue];
	
	if (!isDualDialogue) return;
	
	NSArray<Line*>* left = dialogueBlocks[0];
	NSArray<Line*>* right = dialogueBlocks[1];
	
	NSDictionary* attrs = [self.delegate.textStorage attributesAtIndex:left.firstObject.position effectiveRange:nil];
	NSMutableParagraphStyle* ddPStyle = [attrs[NSParagraphStyleAttributeName] mutableCopy];
		
	NSTextTable* textTable;
	
	if (ddPStyle == nil) ddPStyle = paragraph;
	if (ddPStyle.textBlocks.count > 0) {
		NSTextTableBlock* b = ddPStyle.textBlocks.firstObject;
		if (b != nil) textTable = b.table;
	}
	
	ddPStyle.tailIndent = 0.0;
	
	if (textTable == nil) {
		textTable = [NSTextTable.alloc init];
		textTable.numberOfColumns = 2;
		[textTable setContentWidth:100.0 type:NSTextBlockPercentageValueType];
	}
	
	CGFloat indent = 0.0;
	if (line.isAnyCharacter) {
		indent = DD_BLOCK_CHARACTER_INDENT;
	}
	else if (line.isAnyParenthetical) {
		indent = DD_BLOCK_PARENTHETICAL_INDENT;
	}
	
	ddPStyle.headIndent = indent;
	ddPStyle.firstLineHeadIndent = indent;
	ddPStyle.tailIndent = 0.0;
	[self.delegate.textStorage addAttribute:NSParagraphStyleAttributeName value:ddPStyle range:line.range];
	
	NSTextTableBlock* leftCell = [[NSTextTableBlock alloc] initWithTable:textTable startingRow:0 rowSpan:1 startingColumn:0 columnSpan:1];
	NSTextTableBlock* rightCell = [[NSTextTableBlock alloc] initWithTable:textTable startingRow:0 rowSpan:1 startingColumn:1 columnSpan:1];
	
	[leftCell setContentWidth:50.0 type:NSTextBlockPercentageValueType];
	[rightCell setContentWidth:50.0 type:NSTextBlockPercentageValueType];
		
	NSRange leftRange = NSMakeRange(left.firstObject.position, NSMaxRange(left.lastObject.range) - left.firstObject.position);
	NSRange rightRange = NSMakeRange(right.firstObject.position, NSMaxRange(right.lastObject.range) - right.firstObject.position);
		
	[self.delegate.textStorage enumerateAttribute:NSParagraphStyleAttributeName inRange:leftRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		NSMutableParagraphStyle* pStyle = value;
		pStyle = pStyle.mutableCopy;
		
		pStyle.textBlocks = @[leftCell];
		pStyle.tailIndent = 0.0;
		
		[self.delegate.textStorage addAttribute:NSParagraphStyleAttributeName value:pStyle range:range];
	}];
	[self.delegate.textStorage enumerateAttribute:NSParagraphStyleAttributeName inRange:rightRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		
		NSMutableParagraphStyle* pStyle = value;
		pStyle = pStyle.mutableCopy;
		pStyle.textBlocks = @[rightCell];
		
		[self.delegate.textStorage addAttribute:NSParagraphStyleAttributeName value:pStyle range:range];
	}];

	*/
	/*
	
	
	for (Line* l in left) {
		NSLog(@" --> %@", l);
		NSDictionary* a = [self.delegate.textStorage attributesAtIndex:l.position effectiveRange:nil];
		NSMutableParagraphStyle* pStyle = [a[NSParagraphStyleAttributeName] mutableCopy];
		
		if (pStyle.textBlocks.firstObject != leftCell) pStyle.textBlocks = @[leftCell];
		[self.delegate.textStorage addAttribute:NSParagraphStyleAttributeName value:pStyle range:l.range];
	}
	
	
	for (Line* l in right) {
		NSLog(@" --> %@", l);
		NSDictionary* a = [self.delegate.textStorage attributesAtIndex:l.position effectiveRange:nil];
		NSMutableParagraphStyle* pStyle = [a[NSParagraphStyleAttributeName] mutableCopy];
		
		if (pStyle.textBlocks.firstObject != rightCell) pStyle.textBlocks = @[rightCell];
		[self.delegate.textStorage addAttribute:NSParagraphStyleAttributeName value:pStyle range:line.range];
	}
	*/
}


#pragma mark - Text color

- (void)setTextColorFor:(Line*)line {
	// Foreground color attributes (NOTE: These are TEMPORARY attributes)
	ThemeManager *themeManager = ThemeManager.sharedManager;
	
	// Set the base font color
	[self setForegroundColor:themeManager.textColor line:line range:NSMakeRange(0, line.length)];
	
	// Heading elements can be colorized using [[COLOR COLORNAME]],
	// so let's respect that first
	if (line.isOutlineElement || line.type == synopse) {
		NSColor *color;
		if (line.color.length > 0) {
			color = [BeatColors color:line.color];
		}
		if (color == nil) {
			if (line.type == section) color = themeManager.sectionTextColor;
			else if (line.type == synopse) color = themeManager.synopsisTextColor;
		}
		
		[self setForegroundColor:color line:line range:NSMakeRange(0, line.length)];
	}
	else if (line.type == pageBreak) {
		[self setForegroundColor:themeManager.invisibleTextColor line:line range:NSMakeRange(0, line.length)];
	}
	
	// Enumerate FORMATTING RANGES and make all of them invisible
	[line.formattingRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self setForegroundColor:themeManager.invisibleTextColor line:line range:range];
	}];
	
	// Enumerate note ranges and set it as COMMENT color
//	[line.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
//		[self setForegroundColor:themeManager.commentColor line:line range:range];
//	}];
	
	NSDictionary* notes = line.noteContentsAndRanges;
	for (NSNumber* r in notes.allKeys) {
		NSString* content = notes[r];
		NSRange range = r.rangeValue;
		
		NSColor* color = themeManager.commentColor;
		
		if ([content containsString:@":"]) {
			NSInteger i = [content rangeOfString:@":"].location;
			NSString* colorName = [content substringToIndex:i];
			NSColor* c = [BeatColors color:colorName];
			if (c != nil) color = c;
		}
		
		[self setForegroundColor:color line:line range:range];
	}
	
	// Enumerate title page ranges
	if (line.isTitlePage && line.titleRange.length > 0) {
		[self setForegroundColor:themeManager.commentColor line:line range:line.titleRange];
	}
	
	// Bullets for forced empty lines are invisible, too
	else if ((line.string.containsOnlyWhitespace && line.length >= 2)) {
		[self setForegroundColor:themeManager.invisibleTextColor line:line range:NSMakeRange(0, 2)];
	}
	
	// Color markers
	else if (line.markerRange.length) {
		NSColor *color;
				
		if (line.marker.length == 0) color = [BeatColors color:@"orange"];
		else color = [BeatColors color:line.marker];
		
		NSRange markerRange = line.markerRange;
		
		if (color) [self setForegroundColor:color line:line range:markerRange];
	}
	
}

- (void)stylize:(NSString*)key value:(id)value line:(Line*)line range:(NSRange)range formattingSymbol:(NSString*)sym {
	// Don't add a nil value
	if (!value) return;
	
	NSUInteger symLen = sym.length;
	NSRange effectiveRange;
	
	if (symLen == 0) {
		// Format full range
		effectiveRange = NSMakeRange(range.location, range.length);
	}
	else if (range.length >= 2 * symLen) {
		// Format between characters (ie. *italic*)
		effectiveRange = NSMakeRange(range.location + symLen, range.length - 2 * symLen);
	} else {
		// Format nothing
		effectiveRange = NSMakeRange(range.location + symLen, 0);
	}
	
	if (key.length) [_delegate.textStorage addAttribute:key value:value
												  range:[self globalRangeFromLocalRange:&effectiveRange
																	  inLineAtPosition:line.position]];
}



- (void)setFontStyle:(NSString*)key value:(id)value line:(Line*)line range:(NSRange)range formattingSymbol:(NSString*)sym {
	// Don't add a nil value
	if (!value) return;
	
	NSTextStorage *textStorage = _delegate.textStorage;
	
	NSRange effectiveRange;
	
	if (sym.length == 0) {
		// Format the full range
		effectiveRange = NSMakeRange(range.location, range.length);
	}
	else if (range.length >= 2 * sym.length) {
		// Format between characters (ie. *italic*)
		effectiveRange = NSMakeRange(range.location + sym.length, range.length - 2 * sym.length);
	} else {
		// Format nothing
		effectiveRange = NSMakeRange(range.location + sym.length, 0);
	}
	
	if (key.length) {
		NSRange globalRange = [self globalRangeFromLocalRange:&effectiveRange inLineAtPosition:line.position];
				
		// Add the attribute if needed
		[textStorage enumerateAttribute:key inRange:globalRange options:0 usingBlock:^(id  _Nullable attr, NSRange range, BOOL * _Nonnull stop) {
			if (attr != value) [textStorage addAttribute:key value:value range:range];
		}];
	}
}

- (NSRange)globalRangeFromLocalRange:(NSRange*)range inLineAtPosition:(NSUInteger)position
{
	return NSMakeRange(range->location + position, range->length);
}

#pragma mark - Revision colors

- (void)revisedTextColorFor:(Line*)line {
	if (![BeatUserDefaults.sharedDefaults getBool:BeatSettingShowRevisedTextColor]) return;
	
	NSTextStorage *textStorage = _delegate.textStorage;
	NSLayoutManager *layoutManager = _delegate.layoutManager;
	
	[textStorage enumerateAttribute:BeatRevisions.attributeKey inRange:line.textRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		BeatRevisionItem* revision = value;
		if (revision == nil || revision.type == RevisionNone || revision.type == RevisionRemovalSuggestion) return;
		
		NSColor* color = BeatColors.colors[revision.colorName];
		if (color == nil) return;
		
		[layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:color forCharacterRange:range];
	}];
}

- (void)refreshRevisionTextColors {
	[_delegate.textStorage enumerateAttribute:BeatRevisions.attributeKey inRange:NSMakeRange(0, _delegate.text.length) options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		BeatRevisionItem* revision = value;
		if (revision == nil || revision.type == RevisionNone || revision.type == RevisionRemovalSuggestion) return;
		
		NSColor* color = BeatColors.colors[revision.colorName];
		if (color == nil) return;
		
		[_delegate.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:color forCharacterRange:range];
	}];
}
- (void)refreshRevisionTextColorsInRange:(NSRange)range {
	NSArray* lines = [_delegate.parser linesInRange:range];
	for (Line* line in lines) {
		[self revisedTextColorFor:line];
	}
}


#pragma mark - Forced dialogue

- (void)forceEmptyCharacterCue
{
	NSMutableParagraphStyle *paragraphStyle = [self paragraphStyleForType:character];
	paragraphStyle.maximumLineHeight = BeatEditorFormatting.editorLineHeight;
	paragraphStyle.firstLineHeadIndent = BeatEditorFormatting.characterLeft;
	
	[self.delegate.getTextView setTypingAttributes:@{ NSParagraphStyleAttributeName: paragraphStyle, NSFontAttributeName: _delegate.courier } ];
}

@end

/*
 
 takana on eteenpäin
 lautturi meitä odottaa
 tämä joki
 se upottaa
 
 */
