use ExtUtils::MakeMaker;

    WriteMakefile(
        NAME            => 'Net::SMS::TextmagicRest',
        VERSION_FROM    => 'lib/Net/SMS/TextmagicRest.pm',
        PREREQ_PM  => {
            "REST::Client" => 0,
            "URI::Escape" => 0,
            "JSON" => 0,
            "Carp" => 0,
            "String::CamelCase" => 0,
            "Time::HiRes" => 0,
            "Data::Dumper" => 0,
            "Test::MockModule" => 0,
        }
    );
