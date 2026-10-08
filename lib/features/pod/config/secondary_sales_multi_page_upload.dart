/// Multi-page stock statement upload constants / copy (field users).

const int kSecondarySalesMultiPageMinPages = 2;
const int kSecondarySalesMultiPageMaxPages = 10;

/// Same client-side ceiling used by Secondary Sales / document upload screens.
const int kSecondarySalesMaxUploadBytes = 50 * 1024 * 1024;

const String kSecondarySalesMultiPageEntryLabel =
    'Capture Multi-Page Statement';

const String kSecondarySalesMultiPageMainInstruction =
    'Take photos of all pages of the SAME stock statement for the SAME stockist and SAME month.';

const String kSecondarySalesMultiPageDoNotMixWarning =
    'Do not mix pages from different stockists or different months.';

const String kSecondarySalesMultiPageSupportingText =
    'Take photos of all pages belonging to the same stockist and same month.';

const String kSecondarySalesMultiPageWarning =
    'Please make sure all pages belong to the SAME stockist and SAME month.';

const String kSecondarySalesMultiPageConfirmQuestion =
    'Make sure all pages are from the same stockist and month.';

const String kSecondarySalesMultiPageSameStatementInstruction =
    'Take photos of all pages of the SAME stock statement for the SAME stockist and SAME month.';

const String kSecondarySalesMultiPageEmptyPagesMessage =
    'Please capture at least 2 pages for a multi-page statement.';

const String kSecondarySalesMultiPageMaxPagesMessage =
    'You can upload a maximum of 10 pages.';

const String kSecondarySalesMultiPageMissingStockistMessage =
    'Please select a stockist.';

const String kSecondarySalesMultiPageMissingMonthMessage =
    'Please select a month.';

const String kSecondarySalesMultiPageImagesTooLargeMessage =
    'Images are too large. Please retake the pages using a lower image size.';

const String kSecondarySalesMultiPageUploadInterruptedMessage =
    'Upload interrupted. Your statement has not been submitted completely. Please retry.';

const String kSecondarySalesMultiPageServerErrorMessage =
    'Unable to upload the statement. Please try again.';

String secondarySalesMultiPageConfirmCount(int pages) =>
    'These pages will be processed together as ONE stock statement.';

String secondarySalesMultiPageUploadedTogether(int pages) =>
    '$pages pages will be processed together.';
