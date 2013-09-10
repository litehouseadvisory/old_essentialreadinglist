class BooksController < ApplicationController
  
  
  def new
    @book = Book.new
  end

  def index
    @books = Book.paginate(page: params[:page], :per_page => 10)
  end

  def show
    @book = Book.find(params[:id])
  end

  def create
    @book = Book.new(book_params)
    if @book.save
      flash[:success] = "A new book is added to the GWERL"
      redirect_to @book
    else
      render :new
    end
  end

  def destroy
    Book.find(params[:id]).destroy
    flash[:success] = "Book deleted."
    redirect_to books_url
  end

  def edit
    @book = Book.find(params[:id])
  end

  def update
    @book = Book.find(params[:id])
    if @book.update_attributes(book_params)
      flash[:success] =  "Book updated"
      redirect_to @book
    else
      render 'edit'
    end
  end
  
  def search
    begin
      search_criterion = params[:search_criterion]
      search_value = params[:q]
      book_details = nil
      case search_criterion 
        when "ASIN"
          book_params = lookup_book_via_ASIN(search_value) 
          @book = Book.new(book_params) unless book_params.nil?
          render 'new'
        else
          book_details =  lookup_book_via(search_criterion, search_value)
          if book_details.nil?
            flash[:error] = "Nothing found"
            redirect_to new_book_path
          else
            author, publisher, amazon_url, isbn = "unknown "
            author = book_details.authors.first["name"] unless book_details.authors.nil?
            publisher = book_details.publishers[0]["name"] unless book_details.publishers.nil?
            isbn = book_details.identifiers["isbn_10"].to_s[2..11] unless book_details.identifiers.nil?
            if !isbn.nil?
              search_value = isbn
              search_criterion = "Isbn"
            end
            if book_details.cover.nil?
              img_url = lookup_image_on_Amazon(isbn)
            else
              img_url = book_details.cover["large"]
            end
            amazon_url = amazon_url(isbn) unless isbn.nil?
            book_params = {:title => book_details.title, :authors => author, :publisher => publisher, :identifier => search_value, :identifier_type => search_criterion, :img_url => img_url } 
            @book = Book.new(book_params)
            render 'new'
          end
        end
      rescue
        logger.error "Search returned an unexpected error" 
        flash[:error] = "An error occurred whilst searching external libraries"
        redirect_to new_book_path
      end
  end
  
  def search_gwerl
    search_criterion = params[:search_criterion]
    search_value = params[:q]
    
    return_whatever = nil
    
    if return_whatever.nil?
      flash[:error] = "Nothing found"
      redirect_to books_path
    else
      
    end
  end
  
  def lookup_book_via(search_criterion, search_value)
    case search_criterion
    when "Isbn"
      book_details = lookup_book_via_isbn(search_value)
    when "Olid"
      book_details = lookup_book_via_olid(search_value)
    when "title"
      book_details = lookup_book_via_title(search_value)
    when "author"
      book_details = lookup_book_via_author(search_value)
    else
      flash[:error]= "Invalid serach criterion: #{search_criterion}"
      book_details = nil
    end
  end
  
  def lookup_book_via_isbn(isbn)
    begin
      data = Openlibrary::Data
      book_details = data.find_by_isbn(isbn)
    rescue  => e
      logger.error "Openlibrary API DATA Isbn error"
    end
  end
  
  def lookup_book_via_olid(olid)
    begin
      client = Openlibrary::Client.new
      book = client.book(olid)
    rescue => e
      logger.error "Openlibrary API CLIENT Olid error"
    end
    isbn = book.isbn_10[0]
    book_details = lookup_book_via_isbn(isbn) unless isbn.nil?
  end
  
  def lookup_book_via_ASIN(asin)
    begin
      
      res = Amazon::Ecs.item_lookup(asin, { :response_group => "Medium"})
      book = res.items.first
      
      item_attributes = book.get_element("ItemAttributes")
      img_url = book.get("MediumImage/URL").to_s
      
      title = item_attributes.get("Title")
      author = item_attributes.get("Author")
      publisher = item_attributes.get("Manufacturer")
          
      book_params = {:title => title, :authors => author, :publisher => publisher, :identifier => asin, :identifier_type => "ASIN", :img_url => img_url } 

    rescue => e
      logger.error "Amazon search failed"
      flash[:error] = "Amazon search failed"
    end
    return book_params
  end
  
  def lookup_image_on_Amazon(asin)
    begin
      
      res = Amazon::Ecs.item_lookup(asin, { :response_group => "Medium"})
      book = res.items.first
      img_url = book.get("MediumImage/URL").to_s
      
    rescue => e
      logger.error "Amazon search failed"
      flash[:error] = "Amazon search failed"
    end
    return img_url
  end
  
  def lookup_book_via_title(title)
    begin
      client = Openlibrary::Client.new
      books = client.search(title)
    rescue Exception => e
      logger.error "Openlibrary API CLIENT title error"
    end
    
    if !books[0].nil? && !books[0].isbn.nil?
      isbn = nil
      isbn = books[0].isbn[0]
      book_details = lookup_book_via_isbn(isbn) unless isbn.nil?
    end
    
  end
  
  def lookup_book_via_author(author)
    begin
      client = Openlibrary::Client.new
      books = client.search({ author: "#{author}"} )
    rescue Exception => e
      logger.error "Openlibrary API CLIENT author error"
    end
    isbn = books[0].isbn[0]
    book_details = lookup_book_via_isbn(isbn) unless isbn.nil?
  end
  
  
  private
  
  def book_params
    params.require(:book).permit( :title, :authors, :publisher, :identifier, :identifier_type, :creator_id, :img_url  )
  end
end
