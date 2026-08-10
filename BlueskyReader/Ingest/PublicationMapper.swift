import Foundation

enum PublicationMapper {
    private static let hostToName: [String: String] = [
        "nytimes.com": "The New York Times",
        "washingtonpost.com": "The Washington Post",
        "wsj.com": "The Wall Street Journal",
        "theguardian.com": "The Guardian",
        "bbc.com": "BBC",
        "bbc.co.uk": "BBC",
        "reuters.com": "Reuters",
        "apnews.com": "Associated Press",
        "bloomberg.com": "Bloomberg",
        "cnn.com": "CNN",
        "npr.org": "NPR",
        "theverge.com": "The Verge",
        "wired.com": "WIRED",
        "arstechnica.com": "Ars Technica",
        "techcrunch.com": "TechCrunch",
        "engadget.com": "Engadget",
        "theatlantic.com": "The Atlantic",
        "newyorker.com": "The New Yorker",
        "vox.com": "Vox",
        "slate.com": "Slate",
        "politico.com": "Politico",
        "axios.com": "Axios",
        "propublica.org": "ProPublica",
        "economist.com": "The Economist",
        "ft.com": "Financial Times",
        "forbes.com": "Forbes",
        "fortune.com": "Fortune",
        "businessinsider.com": "Business Insider",
        "cnbc.com": "CNBC",
        "time.com": "TIME",
        "usatoday.com": "USA Today",
        "latimes.com": "Los Angeles Times",
        "chicagotribune.com": "Chicago Tribune",
        "buzzfeednews.com": "BuzzFeed News",
        "huffpost.com": "HuffPost",
        "vice.com": "VICE",
        "gizmodo.com": "Gizmodo",
        "mashable.com": "Mashable",
        "venturebeat.com": "VentureBeat",
        "thehill.com": "The Hill",
        "semafor.com": "Semafor",
        "theintercept.com": "The Intercept",
        "motherjones.com": "Mother Jones",
        "nationalreview.com": "National Review",
        "reason.com": "Reason",
        "nature.com": "Nature",
        "science.org": "Science",
        "scientificamerican.com": "Scientific American",
        "medium.com": "Medium",
        "substack.com": "Substack",
        "github.com": "GitHub",
        "youtube.com": "YouTube",
        "arxiv.org": "arXiv",
        "hbr.org": "Harvard Business Review",
        "espn.com": "ESPN",
        "si.com": "Sports Illustrated",
        "rollingstone.com": "Rolling Stone",
        "pitchfork.com": "Pitchfork",
        "variety.com": "Variety",
        "hollywoodreporter.com": "The Hollywood Reporter",
    ]

    /// `ogSiteName`, if provided (from a page fetch), wins. Otherwise look up the
    /// final host in the bundled mapping, falling back to the bare domain.
    static func publication(ogSiteName: String?, finalURLHost host: String) -> String {
        if let ogSiteName, !ogSiteName.trimmingCharacters(in: .whitespaces).isEmpty {
            return ogSiteName
        }
        if let name = hostToName[host] {
            return name
        }
        return host
    }
}
