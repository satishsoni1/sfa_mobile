// ============================================================
// POD / SECONDARY SALES — API CONFIGURATION
// ------------------------------------------------------------
// Active base URL: https://zydus.mediola.in/pod_dev/api/
// This is the POD-specific backend (NOT the SFA/Himalaya backend).
//
// TODO: Confirm POD API endpoint availability on the SFA/Himalaya
// backend (https://himalaya.globalspace.in/api) before cutover.
//
// External services — do NOT replace with SFA backend:
//   PDF Splitter:  https://anujakkulkarni-splitpdffile.hf.space
//   QR Extractor:  https://anujakkulkarni-envoice-qr-extractor.hf.space
//
// Do NOT change backend URLs without backend confirmation.
// ============================================================

const String API_BASE_URL = "https://himalaya.globalspace.in/api/";
//const String API_BASE_URL = "https://zydus.mediola.in/development/api/";
//const String API_BASE_URL = "http://localhost:8000/api/";

const String API_DOC_UPLOAD_URL = "${API_BASE_URL}grn/upload-pdf";
const String API_POD_UPLOAD_URL = "${API_BASE_URL}pod/upload-pdf";
const String Multi_Api_POD_UPLOAD_URL = "${API_BASE_URL}split-file-processor/process";
const String Multi_Api_POD_UPLOAD_URL_IMAGES = "${API_BASE_URL}pod/upload-multi-allow-images";

const String API_GRNS_URL = "${API_BASE_URL}grns";
const String API_EINV_JSON_URL = "${API_BASE_URL}einv/json";
const String API_STOCKISTS_URL = "${API_BASE_URL}stockists";
const String API_HOSPITALS_URL = "${API_BASE_URL}hospitals";
const String API_LOGIN_URL = "${API_BASE_URL}session/create";
const String API_PODS_URL = "${API_BASE_URL}pods";
const String API_NOTIFICATIONS_URL = "${API_BASE_URL}notifications";
const String API_BATCHES_URL = "${API_BASE_URL}batches";
