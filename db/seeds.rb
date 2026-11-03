# Demo exam for ExamEval. Safe to run more than once.
exam = Exam.find_or_initialize_by(title: "B.Sc. Part I — Environmental Studies (Sample)")
exam.assign_attributes(
  subject: "Environmental Studies",
  course: "B.Sc. Part I",
  instructions: "Answers may be written in Hindi or English. Do not deduct marks for spelling or language choice."
)
exam.save!

questions = [
  {
    number: "1", max_marks: 4,
    prompt: "Define ecosystem and name its two main components.\nपारिस्थितिकी तंत्र को परिभाषित कीजिए और इसके दो मुख्य घटकों के नाम लिखिए।",
    model_answer: <<~TXT.strip,
      An ecosystem is a functional unit of nature in which living organisms interact with each other and with
      their physical (non-living) environment, with flow of energy and cycling of nutrients.
      Its two main components are: (1) biotic components — producers, consumers and decomposers; and
      (2) abiotic components — air, water, soil, sunlight, temperature and minerals.
      पारिस्थितिकी तंत्र प्रकृति की वह क्रियात्मक इकाई है जिसमें जीवधारी आपस में तथा अपने भौतिक (अजैविक) पर्यावरण के साथ
      पारस्परिक क्रिया करते हैं। इसके दो मुख्य घटक हैं: जैविक घटक (उत्पादक, उपभोक्ता, अपघटक) और अजैविक घटक (वायु, जल, मृदा, प्रकाश, ताप)।
    TXT
    rubric: <<~TXT.strip
      - Definition: living organisms interacting with each other and with the non-living environment — 2 marks
        (1 mark if only "living things and environment" without interaction).
      - Names biotic (जैविक) component — 1 mark.
      - Names abiotic (अजैविक) component — 1 mark.
    TXT
  },
  {
    number: "2", max_marks: 5,
    prompt: "What is the greenhouse effect? Give two causes.\nग्रीनहाउस प्रभाव क्या है? इसके दो कारण बताइए।",
    model_answer: <<~TXT.strip,
      The greenhouse effect is the warming of the Earth's surface because gases in the atmosphere (CO2, methane,
      water vapour, nitrous oxide, CFCs) let sunlight in but trap the heat (infra-red radiation) given off by the
      Earth, like the glass of a greenhouse. An enhanced greenhouse effect causes global warming.
      Causes: burning of fossil fuels (coal, petrol, diesel) releasing CO2; deforestation; methane from paddy
      fields, livestock and landfills; use of CFCs; fertilisers releasing nitrous oxide.
      ग्रीनहाउस प्रभाव: वायुमंडल की गैसें (CO2, मीथेन, जलवाष्प) सूर्य का प्रकाश आने देती हैं पर पृथ्वी से निकलने वाली ऊष्मा को रोक लेती हैं,
      जिससे पृथ्वी का तापमान बढ़ता है। कारण: जीवाश्म ईंधन का जलना, वनों की कटाई, मीथेन, CFC।
    TXT
    rubric: <<~TXT.strip
      - Explanation: greenhouse gases trap heat radiated by the Earth, warming the surface — 3 marks
        (2 marks if only "gases trap heat / temperature rises"; 1 mark for a vague mention of warming).
      - First valid cause (e.g. burning fossil fuels, deforestation, methane, CFCs) — 1 mark.
      - Second, different valid cause — 1 mark.
    TXT
  },
  {
    number: "3", max_marks: 6,
    prompt: "Write any three measures to conserve water.\nजल संरक्षण के कोई तीन उपाय लिखिए।",
    model_answer: <<~TXT.strip,
      Any three, each briefly explained: rainwater harvesting (rooftop collection, recharge pits); drip and
      sprinkler irrigation in farming; repairing leaking taps and pipes; reusing/recycling waste water (e.g. for
      gardens, toilets); building check dams, ponds and watershed management; afforestation; avoiding wastage
      in daily use (closing taps, using buckets instead of hoses); awareness campaigns.
      उदाहरण: वर्षा जल संचयन, टपक (ड्रिप) सिंचाई, रिसते नलों की मरम्मत, अपशिष्ट जल का पुनः उपयोग, चेक डैम एवं तालाब, वृक्षारोपण।
    TXT
    rubric: <<~TXT.strip
      - Each of three distinct, valid measures — 2 marks each (1 mark for naming it, 1 mark for a brief explanation).
      - Repeated or overlapping measures earn marks only once. Maximum 6 marks.
    TXT
  }
]

questions.each_with_index do |attrs, i|
  q = exam.questions.find_or_initialize_by(number: attrs[:number])
  q.update!(attrs.merge(position: i + 1))
end

puts "Seeded: #{exam.title} (#{exam.questions.count} questions, #{exam.total_marks.to_f} marks)"
