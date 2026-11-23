glob SETTINGS: dict[str, any] = {
    "AI_BOT": {
        "name": "Docs AI",
        "color": "#8bc6ff"
    },
    "AI_FEATURE_ENABLED": False,
    "AI_FEATURE_BLOCKNOTE_ENABLED": False,
    "AI_FEATURE_LEGACY_ENABLED": True,
    "API_USERS_SEARCH_QUERY_MIN_LENGTH": 3,
    "COLLABORATION_HTTP_FALLBACK_AWARENESS_ENABLED": True,
    "COLLABORATION_HTTP_FALLBACK_JSON_ENABLED": False,
    "COLLABORATION_HTTP_FALLBACK_SYNC_INTERVAL": 10000,
    "COLLABORATION_LOCAL_DOC_RETENTION_DAYS": 30,
    "COLLABORATION_VERSION_GRANULARITY_MS": 60000,
    "COLLABORATION_WS_URL": "ws://127.0.0.1:3002/collaboration/ws/v1/docs",
    "COLLABORATION_WS_INACTIVITY_TIMEOUT": None,
    "CONVERSION_FILE_EXTENSIONS_ALLOWED": [
        ".docx",
        ".md"
    ],
    "CONVERSION_FILE_MAX_SIZE": 20971520,
    "CONVERSION_UPLOAD_ENABLED": False,
    "DOCUMENT_IMAGE_MAX_SIZE": 10485760,
    "DUPLICATE_CHILDREN_FEATURE_ENABLED": True,
    "ENVIRONMENT": "development",
    "FRONTEND_CSS_URL": None,
    "FRONTEND_HOMEPAGE_FEATURE_ENABLED": True,
    "FRONTEND_JS_URL": None,
    "FRONTEND_SILENT_LOGIN_ENABLED": False,
    "FRONTEND_THEME": None,
    "MEDIA_BASE_URL": "http://127.0.0.1:8072",
    "POSTHOG_KEY": None,
    "POSTHOG_HOST": "https://eu.i.posthog.com",
    "LANGUAGES": [
        [
            "en-us",
            "English"
        ],
        [
            "fr-fr",
            "Français"
        ],
        [
            "de-de",
            "Deutsch"
        ],
        [
            "nl-nl",
            "Nederlands"
        ],
        [
            "es-es",
            "Español"
        ]
    ],
    "LANGUAGE_CODE": "en-us",
    "REACTIONS_MAX_PER_COMMENT": 15,
    "SENTRY_DSN": None,
    "TRASHBIN_CUTOFF_DAYS": 30,
    "theme_customization": {
        "footer": {
            "default": {
                "logo": {
                    "src": "/assets/icon-docs.svg",
                    "alt": "Docs Logo",
                    "width": 54,
                    "height": 63,
                    "style": {
                        "width": "54px",
                        "height": "auto"
                    },
                    "withTitle": True
                },
                "externalLinks": [
                    {
                        "label": "GitHub",
                        "href": "https://github.com/suitenumerique/docs/"
                    },
                    {
                        "label": "DINUM",
                        "href": "https://www.numerique.gouv.fr/dinum/"
                    },
                    {
                        "label": "ZenDiS",
                        "href": "https://zendis.de/"
                    },
                    {
                        "label": "BlockNote.js",
                        "href": "https://www.blocknotejs.org/"
                    }
                ],
                "bottomInformation": {
                    "label": "Unless otherwise stated, all content on this site is under",
                    "link": {
                        "label": "licence etalab-2.0",
                        "href": "https://github.com/etalab/licence-ouverte/blob/master/LO.md"
                    }
                }
            },
            "en": {
                "legalLinks": [
                    {
                        "label": "Legal Notice",
                        "href": "#"
                    },
                    {
                        "label": "Personal data and cookies",
                        "href": "#"
                    },
                    {
                        "label": "Accessibility",
                        "href": "#"
                    }
                ],
                "bottomInformation": {
                    "label": "Unless otherwise stated, all content on this site is under",
                    "link": {
                        "label": "licence MIT",
                        "href": "https://github.com/suitenumerique/docs/blob/main/LICENSE"
                    }
                }
            },
            "fr": {
                "legalLinks": [
                    {
                        "label": "Mentions légales",
                        "href": "#"
                    },
                    {
                        "label": "Données personnelles et cookies",
                        "href": "#"
                    },
                    {
                        "label": "Accessibilité",
                        "href": "#"
                    }
                ],
                "bottomInformation": {
                    "label": "Sauf mention contraire, tout le contenu de ce site est sous",
                    "link": {
                        "label": "licence MIT",
                        "href": "https://github.com/suitenumerique/docs/blob/main/LICENSE"
                    }
                }
            },
            "de": {
                "legalLinks": [
                    {
                        "label": "Impressum",
                        "href": "#"
                    },
                    {
                        "label": "Personenbezogene Daten und Cookies",
                        "href": "#"
                    },
                    {
                        "label": "Barrierefreiheit",
                        "href": "#"
                    }
                ],
                "bottomInformation": {
                    "label": "Sofern nicht anders angegeben, steht der gesamte Inhalt dieser Website unter",
                    "link": {
                        "label": "licence MIT",
                        "href": "https://github.com/suitenumerique/docs/blob/main/LICENSE"
                    }
                }
            },
            "nl": {
                "legalLinks": [
                    {
                        "label": "Wettelijke bepalingen",
                        "href": "#"
                    },
                    {
                        "label": "Persoonlijke gegevens en cookies",
                        "href": "#"
                    },
                    {
                        "label": "Toegankelijkheid",
                        "href": "#"
                    }
                ],
                "bottomInformation": {
                    "label": "Tenzij anders vermeld, is alle inhoud van deze site ondergebracht onder",
                    "link": {
                        "label": "licence MIT",
                        "href": "https://github.com/suitenumerique/docs/blob/main/LICENSE"
                    }
                }
            }
        },
        "home": {
            "with-proconnect": False,
            "icon-banner": {
                "src": "/assets/icon-docs.svg",
                "width": 64,
                "height": 74,
                "style": {
                    "width": "64px",
                    "height": "auto"
                },
                "alt": ""
            }
        },
        "header": {
            "logo": {},
            "icon": {
                "src": "/assets/icon-docs.svg",
                "width": 40,
                "height": 40,
                "style": {
                    "width": "40px",
                    "height": "auto"
                },
                "alt": "",
                "withTitle": True
            }
        },
        "favicon": {
            "light": {
                "href": "/assets/favicon-light.png",
                "type": "image/png"
            },
            "dark": {
                "href": "/assets/favicon-dark.png",
                "type": "image/png"
            }
        },
        "onboarding": {
            "enabled": True,
            "learn_more_url": "",
            "ready_template_url": ""
        },
        "help": {
            "documentation_url": "",
            "support_mailto": "",
            "legal_links": {
                "personal_data": "",
                "terms_of_use": "",
                "accessibility_statement": "",
                "legal_notice": ""
            }
        }
    },
    "RELEASE_VERSION": "6.1.0"
};

def:pub config -> Reply;
