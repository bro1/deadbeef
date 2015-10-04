#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#include "playlist.h"
#include "tf.h"

@interface TitleFormatting : XCTestCase {
    playItem_t *it;
    ddb_tf_context_t ctx;
}
@end

@implementation TitleFormatting

- (void)setUp {
    [super setUp];

    pl_init ();

    it = pl_item_alloc_init ("testfile.flac", "stdflac");

    memset (&ctx, 0, sizeof (ctx));
    ctx._size = sizeof (ddb_tf_context_t);
    ctx.it = (DB_playItem_t *)it;
    ctx.plt = NULL;
}

- (void)tearDown {
    pl_item_unref (it);
    pl_free ();

    [super tearDown];
}

- (void)test_Literal_ReturnsLiteral {
    char *bc = tf_compile("hello world");
    char buffer[20];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"hello world" isEqualToString:[NSString stringWithUTF8String:buffer]]);
}

- (void)test_AlbumArtistDash4DigitYearSpaceAlbum_ReturnsCorrectResult {
    pl_add_meta (it, "album artist", "TheAlbumArtist");
    pl_add_meta (it, "year", "12345678");
    pl_add_meta (it, "album", "TheNameOfAlbum");

    char *bc = tf_compile("%album artist% - ($left($meta(year),4)) %album%");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"TheAlbumArtist - (1234) TheNameOfAlbum" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_Unicode_AlbumArtistDash4DigitYearSpaceAlbum_ReturnsCorrectResult {
    pl_add_meta (it, "album artist", "ИсполнительДанногоАльбома");
    pl_add_meta (it, "year", "12345678");
    pl_add_meta (it, "album", "Альбом");

    char *bc = tf_compile("%album artist% - ($left($meta(year),4)) %album%");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"ИсполнительДанногоАльбома - (1234) Альбом" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_TotalDiscsGreaterThan1_ReturnsExpectedResult {
    pl_add_meta (it, "disctotal", "20");
    pl_add_meta (it, "disc", "18");

    char *bc = tf_compile("$if($greater(%totaldiscs%,1),- Disc: %discnumber%/%totaldiscs%)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"- Disc: 18/20" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_AlbumArtistSameAsArtist_ReturnsBlankTrackArtist {
    pl_add_meta (it, "artist", "Artist Name");
    pl_add_meta (it, "album artist", "Artist Name");

    char *bc = tf_compile("%track artist%");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_TrackArtistIsUndef_ReturnsBlankTrackArtist {
    pl_add_meta (it, "album artist", "Artist Name");

    char *bc = tf_compile("%track artist%");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_TrackArtistIsDefined_ReturnsTheTrackArtist {
    pl_add_meta (it, "artist", "Track Artist Name");
    pl_add_meta (it, "album artist", "Album Artist Name");

    char *bc = tf_compile("%track artist%");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"Track Artist Name" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_Add10And2_Gives12 {
    char *bc = tf_compile("$add(10,2)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"12" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_StrcmpChannelsMono_GivesMo {
    char *bc = tf_compile("$if($strcmp(%channels%,mono),mo,st)");
    pl_replace_meta (it, ":CHANNELS", "1");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"mo" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_StrcmpChannelsMono_GivesSt {
    char *bc = tf_compile("$if($strcmp(%channels%,mono),mo,st)");
    pl_replace_meta (it, ":CHANNELS", "2");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"st" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_SimpleExpr_Performance {
    char *bc = tf_compile("simple expr");

    [self measureBlock:^{
        char buffer[20];
        tf_eval (&ctx, bc, buffer, sizeof (buffer));
    }];
    
    tf_free (bc);
}

- (void)test_LongCommentOverflowBuffer_DoesntCrash {
    char longcomment[2048];
    for (int i = 0; i < sizeof (longcomment) - 1; i++) {
        longcomment[i] = (i % 33) + 'a';
    }
    longcomment[sizeof (longcomment)-1] = 0;

    pl_add_meta (it, "comment", longcomment);

    char *bc = tf_compile("$meta(comment)");
    char *buffer = malloc (200);
    XCTAssertNoThrow(tf_eval (&ctx, bc, buffer, 200), @"Crashed!");
    tf_free (bc);
    XCTAssert(!memcmp (buffer, "abcdef", 6), @"The actual output is: %s", buffer);
    free (buffer);
}

- (void)test_ParticularLongExpressionDoesntAllocateZeroBytes {
    pl_replace_meta (it, "artist", "Frank Schätzing");
    pl_replace_meta (it, "year", "1999");
    pl_replace_meta (it, "album", "Tod und Teufel");
    pl_replace_meta (it, "disc", "1");
    pl_replace_meta (it, "disctotal", "4");
    pl_replace_meta (it, ":FILETYPE", "FLAC");
    char *bc = tf_compile("$if($strcmp(%genre%,Classical),%composer%,$if([%band%],%band%,%album artist%)) | ($left(%year%,4)) %album% $if($greater(%totaldiscs%,1),- Disc: %discnumber%/%totaldiscs%) - \\[%codec%\\]");
    char *buffer = malloc (1000);
    XCTAssertNoThrow(tf_eval (&ctx, bc, buffer, 1000), @"Crashed!");
    tf_free (bc);
    free (buffer);
}

- (void)test_If2FirstArgIsTrue_EvalToFirstArg {
    pl_replace_meta (it, "title", "a title");
    char *bc = tf_compile("$if2(%title%,def)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"a title" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_If2FirstArgIsMixedStringTrue_EvalToFirstArg {
    pl_replace_meta (it, "title", "a title");
    pl_replace_meta (it, "artist", "an artist");
    char *bc = tf_compile("$if2(%title%%artist%,def)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"a titlean artist" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_If2FirstArgIsMissingField_EvalToLastArg {
    pl_replace_meta (it, "title", "a title");
    pl_replace_meta (it, "artist", "an artist");
    char *bc = tf_compile("$if2(%garbage%,def)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"def" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_If2FirstArgIsMixedWithGarbageTrue_EvalToFirstArg {
    pl_replace_meta (it, "title", "a title");
    pl_replace_meta (it, "artist", "an artist");
    char *bc = tf_compile("$if2(%garbage%xxx%title%,def)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"xxxa title" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_If2FirstArgIsMixedWithGarbageTailTrue_EvalToFirstArg {
    pl_replace_meta (it, "title", "a title");
    pl_replace_meta (it, "artist", "an artist");
    char *bc = tf_compile("$if2(%title%%garbage%xxx,def)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"a titlexxx" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_If2FirstArgIsFalse_EvalToSecondArg {
    char *bc = tf_compile("$if2(,ghi)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"ghi" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_If3FirstArgIsTrue_EvalToFirstArg {
    pl_replace_meta (it, "title", "a title");
    char *bc = tf_compile("$if3(%title%,def)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"a title" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_If3AllButLastAreFalse_EvalToLastArg {
    char *bc = tf_compile("$if3(,,,,,lastarg)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"lastarg" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_If3OneOfTheArgsBeforeLastIsTrue_EvalToFirstTrueArg {
    char *bc = tf_compile("$if3(,,firstarg,,secondarg,lastarg)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"lastarg" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_IfEqualTrue_EvalsToThen {
    char *bc = tf_compile("$ifequal(100,100,then,else)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"then" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_IfEqualFalse_EvalsToElse {
    char *bc = tf_compile("$ifequal(100,200,then,else)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"else" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_IfGreaterTrue_EvalsToThen {
    char *bc = tf_compile("$ifgreater(200,100,then,else)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"then" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_IfGreaterFalse_EvalsToElse {
    char *bc = tf_compile("$ifgreater(100,200,then,else)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"else" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_GreaterIsTrue_EvalsToTrue {
    char *bc = tf_compile("$if($greater(2,1),istrue,isfalse)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"istrue" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_GreaterIsFalse_EvalsToFalse {
    char *bc = tf_compile("$if($greater(1,2),istrue,isfalse)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"isfalse" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_GreaterIsFalseEmptyArguments_EvalsToFalse {
    char *bc = tf_compile("$if($greater(,),istrue,isfalse)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"isfalse" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_StrCmpEmptyArguments_EvalsToTrue {
    char *bc = tf_compile("$if($strcmp(,),istrue,isfalse)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"istrue" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_StrCmpSameArguments_EvalsToTrue {
    char *bc = tf_compile("$if($strcmp(abc,abc),istrue,isfalse)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"istrue" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_IfLongerTrue_EvalsToTrue {
    char *bc = tf_compile("$iflonger(abcd,ef,istrue,isfalse)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"istrue" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_IfLongerFalse_EvalsToFalse {
    char *bc = tf_compile("$iflonger(ab,cdef,istrue,isfalse)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"isfalse" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_SelectMiddle_EvalsToSelectedValue {
    char *bc = tf_compile("$select(3,10,20,30,40,50)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"30" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_SelectLeftmost_EvalsToSelectedValue {
    char *bc = tf_compile("$select(1,10,20,30,40,50)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"10" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_SelectRightmost_EvalsToSelectedValue {
    char *bc = tf_compile("$select(5,10,20,30,40,50)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"50" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_SelectOutOfBoundsLeft_EvalsToFalse {
    char *bc = tf_compile("$select(0,10,20,30,40,50)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_SelectOutOfBoundsRight_EvalsToFalse {
    char *bc = tf_compile("$select(6,10,20,30,40,50)");
    char buffer[200];
    tf_eval (&ctx, bc, buffer, sizeof (buffer));
    tf_free (bc);
    XCTAssert([@"" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
}

- (void)test_InvalidPercentExpression_WithNullTrack_NoCrash {
    char *bc = tf_compile("deadbeef - %version%");
    char *buffer = malloc (1000);
    ctx.it = NULL;
    XCTAssertNoThrow(tf_eval (&ctx, bc, buffer, 1000), @"Crashed!");
    tf_free (bc);
    free (buffer);
}

- (void)test_Div5by2_Gives3 {
    char *bc = tf_compile("$div(5,2)");
    char *buffer = malloc (1000);
    ctx.it = NULL;
    tf_eval (&ctx, bc, buffer, 1000);
    tf_free (bc);
    XCTAssert([@"3" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
    free (buffer);
}

- (void)test_Div4pt9by1pt9_Gives4 {
    char *bc = tf_compile("$div(4.9,1.9)");
    char *buffer = malloc (1000);
    ctx.it = NULL;
    tf_eval (&ctx, bc, buffer, 1000);
    tf_free (bc);
    XCTAssert([@"4" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
    free (buffer);
}

- (void)test_Div20by2by5_Gives2 {
    char *bc = tf_compile("$div(20,2,5)");
    char *buffer = malloc (1000);
    ctx.it = NULL;
    tf_eval (&ctx, bc, buffer, 1000);
    tf_free (bc);
    XCTAssert([@"2" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
    free (buffer);
}

- (void)test_DivBy0_GivesEmpty {
    char *bc = tf_compile("$div(5,0)");
    char *buffer = malloc (1000);
    ctx.it = NULL;
    tf_eval (&ctx, bc, buffer, 1000);
    tf_free (bc);
    XCTAssert([@"" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
    free (buffer);
}

- (void)test_Max0Arguments_GivesEmpty {
    char *bc = tf_compile("$max()");
    char *buffer = malloc (1000);
    ctx.it = NULL;
    tf_eval (&ctx, bc, buffer, 1000);
    tf_free (bc);
    XCTAssert([@"" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
    free (buffer);
}

- (void)test_MaxOf1and2_Gives2 {
    char *bc = tf_compile("$max(1,2)");
    char *buffer = malloc (1000);
    ctx.it = NULL;
    tf_eval (&ctx, bc, buffer, 1000);
    tf_free (bc);
    XCTAssert([@"2" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
    free (buffer);
}

- (void)test_MaxOf30and50and20_Gives50 {
    char *bc = tf_compile("$max(30,50,20)");
    char *buffer = malloc (1000);
    ctx.it = NULL;
    tf_eval (&ctx, bc, buffer, 1000);
    tf_free (bc);
    XCTAssert([@"50" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
    free (buffer);
}

- (void)test_MinOf1and2_Gives1 {
    char *bc = tf_compile("$min(1,2)");
    char *buffer = malloc (1000);
    ctx.it = NULL;
    tf_eval (&ctx, bc, buffer, 1000);
    tf_free (bc);
    XCTAssert([@"1" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
    free (buffer);
}

- (void)test_MinOf30and50and20_Gives20 {
    char *bc = tf_compile("$min(30,50,20)");
    char *buffer = malloc (1000);
    ctx.it = NULL;
    tf_eval (&ctx, bc, buffer, 1000);
    tf_free (bc);
    XCTAssert([@"20" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
    free (buffer);
}

- (void)test_ModOf3and2_Gives1 {
    char *bc = tf_compile("$mod(3,2)");
    char *buffer = malloc (1000);
    ctx.it = NULL;
    tf_eval (&ctx, bc, buffer, 1000);
    tf_free (bc);
    XCTAssert([@"1" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
    free (buffer);
}

- (void)test_ModOf6and3_Gives0 {
    char *bc = tf_compile("$mod(6,3)");
    char *buffer = malloc (1000);
    ctx.it = NULL;
    tf_eval (&ctx, bc, buffer, 1000);
    tf_free (bc);
    XCTAssert([@"0" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
    free (buffer);
}

- (void)test_ModOf16and18and9_Gives7 {
    char *bc = tf_compile("$mod(16,18,9)");
    char *buffer = malloc (1000);
    ctx.it = NULL;
    tf_eval (&ctx, bc, buffer, 1000);
    tf_free (bc);
    XCTAssert([@"7" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
    free (buffer);
}

- (void)test_Mul2and5_Gives10 {
    char *bc = tf_compile("$mul(2,5)");
    char *buffer = malloc (1000);
    ctx.it = NULL;
    tf_eval (&ctx, bc, buffer, 1000);
    tf_free (bc);
    XCTAssert([@"10" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
    free (buffer);
}

- (void)test_MulOf2and3and4_Gives24 {
    char *bc = tf_compile("$mul(2,3,4)");
    char *buffer = malloc (1000);
    ctx.it = NULL;
    tf_eval (&ctx, bc, buffer, 1000);
    tf_free (bc);
    XCTAssert([@"24" isEqualToString:[NSString stringWithUTF8String:buffer]], @"The actual output is: %s", buffer);
    free (buffer);
}

@end
