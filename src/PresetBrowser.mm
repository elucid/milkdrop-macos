#import "PresetBrowser.h"

@interface MDPresetTable : NSTableView
@property(nonatomic, copy) void (^activateSelection)(void);
@end
@implementation MDPresetTable
- (void)keyDown:(NSEvent*)event {
    if (event.keyCode == 36 || event.keyCode == 76) {
        if (self.activateSelection) self.activateSelection();
    } else [super keyDown:event];
}
@end

@interface MDPresetBrowser ()
@property NSSearchField* search;
@property MDPresetTable* table;
@property NSTextField* countLabel;
@property NSButton* playButton;
@property NSArray<MDPreset*>* matches;
@end

@implementation MDPresetBrowser
- (instancetype)init {
    NSWindow* window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,900,580) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
    self = [super initWithWindow:window];
    if (!self) return nil;
    window.title = @"Preset Browser";
    window.minSize = NSMakeSize(600,360);
    window.releasedWhenClosed = NO;
    window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    NSView* content = window.contentView;
    self.search = [[NSSearchField alloc] initWithFrame:NSZeroRect];
    self.search.placeholderString = @"Search preset name, artist, or category…";
    self.search.accessibilityLabel = @"Search presets";
    self.search.sendsSearchStringImmediately = YES;
    self.search.sendsWholeSearchString = NO;
    self.search.target = self; self.search.action = @selector(searchChanged:);
    self.table = [[MDPresetTable alloc] initWithFrame:NSZeroRect];
    self.table.dataSource = self; self.table.delegate = self;
    self.table.rowHeight = 28;
    self.table.usesAlternatingRowBackgroundColors = YES;
    self.table.allowsMultipleSelection = NO;
    self.table.target = self; self.table.doubleAction = @selector(playSelected:);
    self.table.accessibilityLabel = @"Matching presets";
    NSTableColumn* name = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    name.title = @"Preset"; name.width = 590; name.minWidth = 250;
    NSTableColumn* category = [[NSTableColumn alloc] initWithIdentifier:@"category"];
    category.title = @"Category"; category.width = 250; category.minWidth = 100;
    [self.table addTableColumn:name]; [self.table addTableColumn:category];
    self.table.columnAutoresizingStyle = NSTableViewLastColumnOnlyAutoresizingStyle;
    NSScrollView* scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.documentView = self.table;
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSBezelBorder;
    self.countLabel = [NSTextField labelWithString:@""];
    self.countLabel.textColor = NSColor.secondaryLabelColor;
    self.countLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.playButton = [NSButton buttonWithTitle:@"Play Selected" target:self action:@selector(playSelected:)];
    self.playButton.enabled = NO;
    for (NSView* view in @[self.search,scroll,self.countLabel,self.playButton]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [content addSubview:view];
    }
    [NSLayoutConstraint activateConstraints:@[
        [self.search.topAnchor constraintEqualToAnchor:content.topAnchor constant:16],
        [self.search.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [self.search.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [scroll.topAnchor constraintEqualToAnchor:self.search.bottomAnchor constant:12],
        [scroll.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [scroll.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [scroll.bottomAnchor constraintEqualToAnchor:self.playButton.topAnchor constant:-12],
        [self.playButton.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-12],
        [self.playButton.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [self.countLabel.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [self.countLabel.centerYAnchor constraintEqualToAnchor:self.playButton.centerYAnchor],
        [self.countLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.playButton.leadingAnchor constant:-12]
    ]];
    __weak MDPresetBrowser* weakSelf = self;
    self.table.activateSelection = ^{ [weakSelf playSelected:nil]; };
    [window center];
    return self;
}
- (void)showWindow:(id)sender {
    [self refresh];
    [super showWindow:sender];
    [self.window makeKeyAndOrderFront:sender];
    [self.window makeFirstResponder:self.search];
}
- (void)refresh {
    self.matches = [self.library matchingQuery:self.search.stringValue] ?: @[];
    [self.table reloadData];
    NSUInteger current = [self.matches indexOfObjectPassingTest:^BOOL(MDPreset* preset, NSUInteger, BOOL*) { return [preset.path isEqualToString:self.currentPath]; }];
    if (current != NSNotFound) {
        [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:current] byExtendingSelection:NO];
        [self.table scrollRowToVisible:current];
    } else if (self.matches.count) {
        [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        [self.table scrollRowToVisible:0];
    }
    self.playButton.enabled = self.table.selectedRow >= 0;
    self.countLabel.stringValue = [NSString stringWithFormat:@"%@ of %@ presets · Shuffle pauses while browsing",
        [NSNumberFormatter localizedStringFromNumber:@(self.matches.count) numberStyle:NSNumberFormatterDecimalStyle],
        [NSNumberFormatter localizedStringFromNumber:@(self.library.presets.count) numberStyle:NSNumberFormatterDecimalStyle]];
}
- (void)searchChanged:(id)sender { [self refresh]; }
- (NSInteger)numberOfRowsInTableView:(NSTableView*)tableView { return self.matches.count; }
- (NSView*)tableView:(NSTableView*)tableView viewForTableColumn:(NSTableColumn*)column row:(NSInteger)row {
    NSTableCellView* cell = [tableView makeViewWithIdentifier:column.identifier owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
        cell.identifier = column.identifier;
        NSTextField* label = [NSTextField labelWithString:@""];
        label.translatesAutoresizingMaskIntoConstraints = NO;
        label.lineBreakMode = NSLineBreakByTruncatingTail;
        [cell addSubview:label]; cell.textField = label;
        [NSLayoutConstraint activateConstraints:@[
            [label.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:6],
            [label.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-6],
            [label.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor]]];
    }
    MDPreset* preset = self.matches[row];
    cell.textField.stringValue = [column.identifier isEqualToString:@"name"] ? preset.name : (preset.category.length ? preset.category : @"—");
    cell.toolTip = preset.path;
    return cell;
}
- (void)tableViewSelectionDidChange:(NSNotification*)notification { self.playButton.enabled = self.table.selectedRow >= 0; }
- (void)playSelected:(id)sender {
    NSInteger row = self.table.selectedRow;
    if (row >= 0 && row < (NSInteger)self.matches.count && self.choosePreset) self.choosePreset(self.matches[row]);
}
@end
