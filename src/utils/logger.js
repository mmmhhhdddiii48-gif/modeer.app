function stamp() {
  return new Date().toISOString();
}

function info(message, meta) {
  if (meta) console.log(`[${stamp()}] INFO  ${message}`, meta);
  else console.log(`[${stamp()}] INFO  ${message}`);
}

function warn(message, meta) {
  if (meta) console.warn(`[${stamp()}] WARN  ${message}`, meta);
  else console.warn(`[${stamp()}] WARN  ${message}`);
}

function error(message, meta) {
  if (meta) console.error(`[${stamp()}] ERROR ${message}`, meta);
  else console.error(`[${stamp()}] ERROR ${message}`);
}

module.exports = { info, warn, error };
