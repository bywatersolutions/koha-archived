INSERT INTO  systempreferences (
    variable ,
    value ,
    options ,
    explanation ,
    type
) VALUES (
    'UseDocumentDelivery',
    '0',
    NULL,
    'If ON, give patron''s placing holds the option for document delivery.',
    'YesNo'
);


ALTER TABLE reserves
    CHANGE reservedate reservedate DATETIME NULL DEFAULT NULL,
    CHANGE cancellationdate  cancellationdate DATETIME NULL DEFAULT NULL,
    ADD cancellation_note TEXT NULL AFTER  cancellationdate,
    ADD type ENUM( 'hold', 'document_delivery' ) NOT NULL DEFAULT 'hold',
    ADD dd_title TEXT NULL ,
    ADD dd_authors TEXT NULL ,
    ADD dd_vol_issue_date TEXT NULL ,
    ADD dd_pages TEXT NULL ,
    ADD dd_chapters TEXT NULL;


ALTER TABLE old_reserves
    CHANGE reservedate reservedate DATETIME NULL DEFAULT NULL,
    CHANGE  cancellationdate  cancellationdate DATETIME NULL DEFAULT NULL,
    ADD cancellation_note TEXT NULL AFTER  cancellationdate,
    ADD type ENUM( 'hold', 'document_delivery' ) NOT NULL DEFAULT 'hold',
    ADD dd_title TEXT NULL ,
    ADD dd_authors TEXT NULL ,
    ADD dd_vol_issue_date TEXT NULL ,
    ADD dd_pages TEXT NULL ,
    ADD dd_chapters TEXT NULL;
